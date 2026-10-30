"""
Labels storage and EXIF metadata management.
Maintains data/labels.json with atomic writes and file locking.
Keyed by sha256[:16].
"""

import datetime
import io
import json
import os
import re
from typing import Any, Optional
from filelock import FileLock
from PIL import Image, ExifTags

try:
    import pillow_heif
    pillow_heif.register_heif_opener()
except ImportError:
    pass

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
LABELS_PATH = os.path.join(DATA_DIR, "labels.json")
LABELS_LOCK_PATH = os.path.join(DATA_DIR, ".labels.lock")
IMAGES_RAW_DIR = os.path.join(DATA_DIR, "images", "raw")
IMAGES_PROCESSED_DIR = os.path.join(DATA_DIR, "images", "processed")
RAW_INDEX_PATH = os.path.join(DATA_DIR, "raw_index.json")

VALID_RIPENESS_STAGES = ["Green", "Turning", "Ripe", "Overripe"]
RIPENESS_STAGE_SET = set(VALID_RIPENESS_STAGES)
BUNCH_ID_REGEX = re.compile(r"^[A-Za-z0-9-]+$")


def parse_filename_bunch_id(filename: str) -> Optional[str]:
    """
    Extracts bunch_id from filename prefix '<bunch_id>__<rest>'.
    bunch_id must match ^[A-Za-z0-9-]+$.
    """
    base = os.path.basename(filename)
    if "__" in base:
        prefix = base.split("__", 1)[0]
        if BUNCH_ID_REGEX.match(prefix):
            return prefix
    return None


def get_labels_lock() -> FileLock:
    os.makedirs(DATA_DIR, exist_ok=True)
    return FileLock(LABELS_LOCK_PATH, timeout=30.0)


def parse_exif_date(date_str: str) -> Optional[str]:
    """Converts EXIF date format 'YYYY:MM:DD HH:MM:SS' to ISO 8601 'YYYY-MM-DDTHH:MM:SS'."""
    if not date_str or not isinstance(date_str, str):
        return None
    date_str = date_str.strip()
    match = re.match(r"^(\d{4})[:\-](\d{2})[:\-](\d{2})\s+(\d{2}):(\d{2}):(\d{2})", date_str)
    if match:
        y, m, d, hh, mm, ss = match.groups()
        return f"{y}-{m}-{d}T{hh}:{mm}:{ss}"
    return None


def extract_exif_capture_time(raw_path_or_bytes: Any) -> Optional[str]:
    """
    Reads EXIF capture time (DateTimeOriginal or DateTime) from a raw photo file path or bytes.
    Returns ISO 8601 string or None.
    """
    try:
        if isinstance(raw_path_or_bytes, (str, os.PathLike)):
            if not os.path.exists(raw_path_or_bytes):
                return None
            im = Image.open(raw_path_or_bytes)
        else:
            im = Image.open(io.BytesIO(raw_path_or_bytes))

        exif = im.getexif()
        if not exif:
            return None

        # 1. Check in Exif IFD for DateTimeOriginal (tag 36867) or DateTimeDigitized (36868)
        try:
            ifd = exif.get_ifd(ExifTags.IFD.Exif)
            if ifd:
                for tag_code in (36867, 36868):  # DateTimeOriginal, DateTimeDigitized
                    val = ifd.get(tag_code)
                    if val:
                        parsed = parse_exif_date(str(val))
                        if parsed:
                            return parsed
        except Exception:
            pass

        # 2. Check main EXIF for DateTime (tag 306)
        for tag_id, val in exif.items():
            name = ExifTags.TAGS.get(tag_id, str(tag_id))
            if name in ("DateTimeOriginal", "DateTime"):
                parsed = parse_exif_date(str(val))
                if parsed:
                    return parsed
    except Exception:
        pass
    return None


def load_labels(labels_file: Optional[str] = None, lock_file: Optional[str] = None) -> dict[str, dict[str, Any]]:
    """Loads labels.json under filelock."""
    target_path = labels_file or LABELS_PATH
    lock = FileLock(lock_file, timeout=30.0) if lock_file else get_labels_lock()
    with lock:
        if os.path.exists(target_path):
            try:
                with open(target_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        return data
            except Exception:
                return {}
        return {}


def save_labels(labels: dict[str, dict[str, Any]], labels_file: Optional[str] = None, lock_file: Optional[str] = None) -> None:
    """Atomically saves labels.json under filelock."""
    target_path = labels_file or LABELS_PATH
    lock = FileLock(lock_file, timeout=30.0) if lock_file else get_labels_lock()
    with lock:
        os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
        tmp_path = f"{target_path}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(labels, f, indent=2)
        os.replace(tmp_path, target_path)


def get_label(sha16: str, labels_file: Optional[str] = None) -> Optional[dict[str, Any]]:
    labels = load_labels(labels_file=labels_file)
    return labels.get(sha16)


def set_label(
    sha16: str,
    variety: Optional[str] = None,
    ripeness: Optional[str] = None,
    bunch_id: Optional[str] = None,
    group_id: Optional[str] = None,
    capture_time: Optional[str] = None,
    label_source: str = "manual",
    labels_file: Optional[str] = None,
    lock_file: Optional[str] = None,
) -> dict[str, Any]:
    """Sets or updates a label record atomically."""
    if ripeness is not None and ripeness not in RIPENESS_STAGE_SET:
        raise ValueError(f"Invalid ripeness stage '{ripeness}'. Allowed: {VALID_RIPENESS_STAGES}")

    if bunch_id is not None and bunch_id != "" and not BUNCH_ID_REGEX.match(bunch_id):
        raise ValueError(f"Invalid bunch_id '{bunch_id}'. Must match ^[A-Za-z0-9-]+$")

    target_path = labels_file or LABELS_PATH
    lock = FileLock(lock_file, timeout=30.0) if lock_file else get_labels_lock()
    with lock:
        labels = {}
        if os.path.exists(target_path):
            try:
                with open(target_path, "r", encoding="utf-8") as f:
                    labels = json.load(f)
            except Exception:
                labels = {}

        now_iso = datetime.datetime.now().isoformat()
        existing = labels.get(sha16, {})

        new_variety = variety if variety is not None else existing.get("variety", "Unknown")
        new_ripeness = ripeness if ripeness is not None else existing.get("ripeness")
        new_bunch = bunch_id if bunch_id is not None else existing.get("bunch_id")
        
        # group_id = bunch_id when present; otherwise "legacy_<Class>"
        if group_id is not None:
            new_group = group_id
        elif new_bunch:
            new_group = new_bunch
        else:
            new_group = existing.get("group_id") or f"legacy_{new_variety}"

        rec = {
            "variety": new_variety,
            "ripeness": new_ripeness,
            "bunch_id": new_bunch,
            "group_id": new_group,
            "capture_time": capture_time if capture_time is not None else existing.get("capture_time"),
            "label_source": label_source if label_source else existing.get("label_source", "manual"),
            "updated_at": now_iso,
        }
        labels[sha16] = rec

        os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
        tmp_path = f"{target_path}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(labels, f, indent=2)
        os.replace(tmp_path, target_path)
        return rec


def backfill_labels() -> dict[str, Any]:
    """
    Backfills variety for every existing processed image from its class folder,
    with ripeness=null, bunch_id=null, and group_id="legacy_<Class>".
    """
    labels = load_labels()
    updated_count = 0
    total_images = 0

    # Build raw_hash mapping from raw_index.json or raw directory scan
    raw_hash_to_path: dict[str, str] = {}
    if os.path.exists(RAW_INDEX_PATH):
        try:
            with open(RAW_INDEX_PATH, "r", encoding="utf-8") as f:
                raw_idx = json.load(f)
                for rel_path, full_hash in raw_idx.items():
                    raw_hash_to_path[full_hash[:16]] = os.path.join(IMAGES_RAW_DIR, rel_path)
        except Exception:
            pass

    if not os.path.isdir(IMAGES_PROCESSED_DIR):
        return {"total": 0, "updated": 0}

    for cname in sorted(os.listdir(IMAGES_PROCESSED_DIR)):
        cdir = os.path.join(IMAGES_PROCESSED_DIR, cname)
        if not os.path.isdir(cdir) or cname.startswith("."):
            continue

        for fname in sorted(os.listdir(cdir)):
            if not fname.lower().endswith((".jpg", ".jpeg", ".png")):
                continue

            sha16 = os.path.splitext(fname)[0]
            total_images += 1

            if sha16 not in labels:
                raw_p = raw_hash_to_path.get(sha16)
                capture_time = None
                bunch_id = None
                if raw_p and os.path.exists(raw_p):
                    capture_time = extract_exif_capture_time(raw_p)
                    bunch_id = parse_filename_bunch_id(raw_p)

                labels[sha16] = {
                    "variety": cname,
                    "ripeness": None,
                    "bunch_id": bunch_id,
                    "group_id": bunch_id if bunch_id else f"legacy_{cname}",
                    "capture_time": capture_time,
                    "label_source": "backfill",
                    "updated_at": datetime.datetime.now().isoformat(),
                }
                updated_count += 1
            else:
                changed = False
                rec = labels[sha16]
                if "bunch_id" not in rec:
                    raw_p = raw_hash_to_path.get(sha16)
                    bunch_id = parse_filename_bunch_id(raw_p) if raw_p else None
                    rec["bunch_id"] = bunch_id
                    changed = True

                # Update group_id to legacy_<Class> if it was unassigned or sha16
                if not rec.get("bunch_id") and (not rec.get("group_id") or rec.get("group_id") == sha16):
                    rec["group_id"] = f"legacy_{cname}"
                    changed = True
                elif rec.get("bunch_id"):
                    rec["group_id"] = rec["bunch_id"]
                    changed = True

                if not rec.get("capture_time"):
                    raw_p = raw_hash_to_path.get(sha16)
                    if raw_p and os.path.exists(raw_p):
                        ctime = extract_exif_capture_time(raw_p)
                        if ctime:
                            rec["capture_time"] = ctime
                            changed = True

                if changed:
                    rec["updated_at"] = datetime.datetime.now().isoformat()
                    updated_count += 1

    save_labels(labels)
    return {"total": total_images, "updated": updated_count, "labels_count": len(labels)}
