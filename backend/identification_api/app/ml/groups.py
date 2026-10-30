import os
import sys
import json
import argparse
from datetime import datetime
from collections import defaultdict
from typing import Any, Dict, List, Optional, Tuple
from PIL import Image

from app.ml.labels import (
    load_labels,
    save_labels,
    DATA_DIR,
)

DIAGNOSTICS_DIR = os.path.join(DATA_DIR, "diagnostics")
PROCESSED_DIR = os.path.join(DATA_DIR, "images", "processed")
RAW_DIR = os.path.join(DATA_DIR, "images", "raw")


def compute_dhash(image_path: str, hash_size: int = 8) -> int:
    """
    Computes a 64-bit difference hash (dHash) for an image.
    Resizes image to (hash_size + 1, hash_size) in grayscale,
    and compares adjacent pixels.
    """
    with Image.open(image_path) as img:
        img = img.convert("L").resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
        pixels = list(img.getdata())
        diff = 0
        row_stride = hash_size + 1
        for row in range(hash_size):
            row_start = row * row_stride
            for col in range(hash_size):
                left = pixels[row_start + col]
                right = pixels[row_start + col + 1]
                diff = (diff << 1) | (1 if left > right else 0)
        return diff


def hamming_distance(h1: int, h2: int) -> int:
    return (h1 ^ h2).bit_count()


class UnionFind:
    def __init__(self, elements: List[str]):
        self.parent = {elem: elem for elem in elements}
        self.rank = {elem: 0 for elem in elements}

    def find(self, x: str) -> str:
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]

    def union(self, x: str, y: str):
        root_x = self.find(x)
        root_y = self.find(y)
        if root_x == root_y:
            return
        if self.rank[root_x] < self.rank[root_y]:
            self.parent[root_x] = root_y
        elif self.rank[root_x] > self.rank[root_y]:
            self.parent[root_y] = root_x
        else:
            self.parent[root_y] = root_x
            self.rank[root_x] += 1


def parse_capture_time(dt_str: Optional[str]) -> Optional[datetime]:
    if not dt_str:
        return None
    try:
        return datetime.fromisoformat(dt_str)
    except Exception:
        return None


def find_image_path(sha16: str, variety: Optional[str]) -> Optional[str]:
    # Check processed folder
    if variety:
        proc_path = os.path.join(PROCESSED_DIR, variety, f"{sha16}.jpg")
        if os.path.isfile(proc_path):
            return proc_path

    # Walk processed
    if os.path.isdir(PROCESSED_DIR):
        for v in os.listdir(PROCESSED_DIR):
            cand = os.path.join(PROCESSED_DIR, v, f"{sha16}.jpg")
            if os.path.isfile(cand):
                return cand
    return None


def compute_groups(
    dhash_threshold: Optional[int] = None,
    time_window_minutes: Optional[float] = None,
    save_to_labels: bool = True,
    write_report: bool = True,
) -> Tuple[Dict[str, str], Dict[str, Any]]:
    """
    Groups images of the same variety using connected components based on:
    1. dHash Hamming distance <= dhash_threshold (default 6 or env DHASH_THRESHOLD)
    2. EXIF capture times within time_window_minutes (default 30 or env GROUP_TIME_WINDOW_MINUTES)
    
    Images with no near-duplicate neighbors or capture info within window
    receive their own sha16 as group_id.
    """
    if dhash_threshold is None:
        dhash_threshold = int(os.environ.get("DHASH_THRESHOLD", 6))
    if time_window_minutes is None:
        time_window_minutes = float(os.environ.get("GROUP_TIME_WINDOW_MINUTES", 0.0))
    time_window_seconds = time_window_minutes * 60.0

    labels = load_labels()
    by_class_non_bunch: Dict[str, List[str]] = defaultdict(list)
    bunch_images: Dict[str, str] = {}  # sha16 -> bunch_id

    for sha16, rec in labels.items():
        v = rec.get("variety", "Unknown")
        bunch_id = rec.get("bunch_id")
        if bunch_id:
            bunch_images[sha16] = bunch_id
        else:
            by_class_non_bunch[v].append(sha16)

    dhashes: Dict[str, Optional[int]] = {}
    timestamps: Dict[str, Optional[datetime]] = {}

    print(f"[GROUPS] Computing dHash for {len(labels)} images (bunch images: {len(bunch_images)}, non-bunch: {sum(len(l) for l in by_class_non_bunch.values())})...")
    for sha16, rec in labels.items():
        v = rec.get("variety")
        img_path = find_image_path(sha16, v)
        if img_path:
            try:
                dhashes[sha16] = compute_dhash(img_path)
            except Exception:
                dhashes[sha16] = None
        else:
            dhashes[sha16] = None

        timestamps[sha16] = parse_capture_time(rec.get("capture_time"))

    # Process dHash connected components only among images WITHOUT a bunch_id
    all_non_bunch_sha = [s for sha_list in by_class_non_bunch.values() for s in sha_list]
    uf = UnionFind(all_non_bunch_sha)
    edge_count = 0
    dhash_edge_count = 0
    time_edge_count = 0
    both_edge_count = 0

    for variety, sha_list in by_class_non_bunch.items():
        n = len(sha_list)
        for i in range(n):
            s1 = sha_list[i]
            h1 = dhashes.get(s1)
            t1 = timestamps.get(s1)
            for j in range(i + 1, n):
                s2 = sha_list[j]
                h2 = dhashes.get(s2)
                t2 = timestamps.get(s2)

                is_dhash_match = False
                if h1 is not None and h2 is not None:
                    if hamming_distance(h1, h2) <= dhash_threshold:
                        is_dhash_match = True

                is_time_match = False
                if time_window_seconds > 0 and t1 is not None and t2 is not None:
                    diff_sec = abs((t1 - t2).total_seconds())
                    if diff_sec <= time_window_seconds:
                        is_time_match = True

                if is_dhash_match or is_time_match:
                    uf.union(s1, s2)
                    edge_count += 1
                    if is_dhash_match and is_time_match:
                        both_edge_count += 1
                    elif is_dhash_match:
                        dhash_edge_count += 1
                    else:
                        time_edge_count += 1

    group_map: Dict[str, str] = {}
    grouped_clusters: Dict[str, List[str]] = defaultdict(list)

    # 1. Images with bunch_id get group_id = bunch_id
    for sha16, b_id in bunch_images.items():
        group_map[sha16] = b_id
        grouped_clusters[b_id].append(sha16)

    # 2. Images without bunch_id: group_id = "legacy_<Class>" (one group per class)
    # dHash linking connects within the class and respects near-duplicate grouping
    for variety, sha_list in by_class_non_bunch.items():
        legacy_group_id = f"legacy_{variety}"
        for s in sha_list:
            group_map[s] = legacy_group_id
            grouped_clusters[legacy_group_id].append(s)

    # Update labels.json
    if save_to_labels:
        for sha16, gid in group_map.items():
            if sha16 in labels:
                labels[sha16]["group_id"] = gid
                if sha16 in bunch_images:
                    labels[sha16]["bunch_id"] = bunch_images[sha16]
                elif "bunch_id" not in labels[sha16]:
                    labels[sha16]["bunch_id"] = None
        save_labels(labels)
        print(f"[GROUPS] Updated {len(group_map)} group IDs in data/labels.json.")

    # Generate statistics
    group_sizes = [len(m) for m in grouped_clusters.values()]
    size_dist: Dict[int, int] = defaultdict(int)
    for sz in group_sizes:
        size_dist[sz] += 1

    # Sort largest groups
    sorted_groups = sorted(grouped_clusters.items(), key=lambda kv: len(kv[1]), reverse=True)

    all_sha = list(labels.keys())
    by_class: Dict[str, List[str]] = defaultdict(list)
    for sha16, rec in labels.items():
        v = rec.get("variety", "Unknown")
        by_class[v].append(sha16)

    report_data = {
        "total_images": len(all_sha),
        "total_groups": len(grouped_clusters),
        "singleton_groups": size_dist.get(1, 0),
        "multi_image_groups": sum(cnt for sz, cnt in size_dist.items() if sz > 1),
        "dhash_threshold": dhash_threshold,
        "time_window_minutes": time_window_minutes,
        "edge_count": edge_count,
        "dhash_edge_count": dhash_edge_count,
        "time_edge_count": time_edge_count,
        "both_edge_count": both_edge_count,
        "size_distribution": dict(sorted(size_dist.items())),
        "largest_groups": sorted_groups[:20],
        "by_class": {},
    }

    for variety, sha_list in by_class.items():
        class_gids = set(group_map[s] for s in sha_list)
        class_group_sizes = [len([s for s in grouped_clusters[gid] if s in sha_list]) for gid in class_gids]
        report_data["by_class"][variety] = {
            "image_count": len(sha_list),
            "group_count": len(class_gids),
            "max_group_size": max(class_group_sizes) if class_group_sizes else 0,
        }

    if write_report:
        os.makedirs(DIAGNOSTICS_DIR, exist_ok=True)
        report_path = os.path.join(DIAGNOSTICS_DIR, "groups_report.md")
        _write_markdown_report(report_path, report_data, labels)
        print(f"[GROUPS] Wrote diagnostic report to {report_path}")

    return group_map, report_data


def _write_markdown_report(report_path: str, data: dict, labels: dict):
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("# Dataset Grouping and De-duplication Report\n\n")
        f.write(f"- **Generated at:** {datetime.now().isoformat()}\n")
        f.write(f"- **Total Images:** {data['total_images']}\n")
        f.write(f"- **Total Groups:** {data['total_groups']}\n")
        f.write(f"- **Singletons (Unique Images):** {data['singleton_groups']}\n")
        f.write(f"- **Multi-Image Groups (Clusters):** {data['multi_image_groups']}\n")
        f.write(f"- **dHash Hamming Threshold:** <= {data['dhash_threshold']}\n")
        f.write(f"- **EXIF Time Window:** <= {data['time_window_minutes']} minutes\n")
        f.write(f"- **Total Connected Edges:** {data['edge_count']} "
                f"(dHash only: {data['dhash_edge_count']}, Time only: {data['time_edge_count']}, Both: {data['both_edge_count']})\n\n")

        f.write("## Per-Class Summary\n\n")
        f.write("| Variety Class | Total Images | Groups | Max Group Size |\n")
        f.write("| :--- | :--- | :--- | :--- |\n")
        for cls_name, info in sorted(data["by_class"].items()):
            f.write(f"| {cls_name} | {info['image_count']} | {info['group_count']} | {info['max_group_size']} |\n")
        f.write("\n")

        f.write("## Group Size Distribution\n\n")
        f.write("| Group Size | Number of Groups | Total Images in Size |\n")
        f.write("| :--- | :--- | :--- |\n")
        for sz, count in data["size_distribution"].items():
            f.write(f"| {sz} | {count} | {sz * count} |\n")
        f.write("\n")

        f.write("## Largest Groups (Top 20)\n\n")
        f.write("| Group ID | Class | Image Count | Capture Time Range | Sample Hashes |\n")
        f.write("| :--- | :--- | :--- | :--- | :--- |\n")
        for gid, members in data["largest_groups"]:
            if len(members) <= 1:
                break
            v = labels.get(members[0], {}).get("variety", "Unknown")
            times = [labels[m].get("capture_time") for m in members if labels.get(m, {}).get("capture_time")]
            times_clean = [t for t in times if t]
            time_range = "N/A"
            if times_clean:
                time_range = f"{min(times_clean)[:19]} to {max(times_clean)[:19]}"
            sample_str = ", ".join(members[:4]) + ("..." if len(members) > 4 else "")
            f.write(f"| `{gid}` | {v} | {len(members)} | {time_range} | {sample_str} |\n")
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Compute image groups based on dHash and EXIF timestamps.")
    parser.add_argument("--dhash-threshold", type=int, default=None, help="Hamming distance threshold (default: 6)")
    parser.add_argument("--time-window", type=float, default=None, help="Time window in minutes (default: 30)")
    parser.add_argument("--no-save", action="store_true", help="Do not write back to labels.json")
    args = parser.parse_args()

    compute_groups(
        dhash_threshold=args.dhash_threshold,
        time_window_minutes=args.time_window,
        save_to_labels=not args.no_save,
        write_report=True,
    )


if __name__ == "__main__":
    main()
