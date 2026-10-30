import argparse
import os
import sys
from typing import Optional
from app.ml.dataset import ingest


def import_dataset(folder_path: str, bunch_id: Optional[str] = None):
    if not os.path.isdir(folder_path):
        print(f"ERROR: Directory '{folder_path}' does not exist.")
        sys.exit(1)

    subfolders = [
        d for d in os.listdir(folder_path)
        if os.path.isdir(os.path.join(folder_path, d))
    ]

    if not subfolders:
        print(f"No subfolders found in '{folder_path}'. Expected class folders matching 'Name_Banana'.")
        return

    print(f"\n=======================================================")
    print(f" Importing dataset from: {folder_path}")
    print(f" Classes found ({len(subfolders)}): {', '.join(subfolders)}")
    if bunch_id:
        print(f" Bunch ID assigned: {bunch_id}")
    print(f"=======================================================\n")

    grand_total_added = 0
    grand_total_dupe = 0
    grand_total_rejected = 0

    for class_name in sorted(subfolders):
        class_dir = os.path.join(folder_path, class_name)
        files = [
            f for f in os.listdir(class_dir)
            if not f.startswith(".") and os.path.isfile(os.path.join(class_dir, f))
        ]

        added = 0
        duplicate = 0
        rejected = 0

        print(f"Processing '{class_name}' ({len(files)} files)...")

        for filename in files:
            file_path = os.path.join(class_dir, filename)
            try:
                with open(file_path, "rb") as f:
                    file_bytes = f.read()

                result = ingest(class_name, file_bytes, filename, bunch_id=bunch_id)
                status = result.get("status")

                if status == "added":
                    added += 1
                elif status == "duplicate":
                    duplicate += 1
                else:
                    rejected += 1
                    print(f"   [REJECTED] {filename}: {result.get('reason')}")
            except Exception as e:
                rejected += 1
                print(f"   [ERROR] Failed to read {filename}: {e}")

        grand_total_added += added
        grand_total_dupe += duplicate
        grand_total_rejected += rejected

        print(f"  -> Added: {added} | Duplicate: {duplicate} | Rejected: {rejected}\n")

    print(f"=======================================================")
    print(f" Import Complete!")
    print(f" Total Added     : {grand_total_added}")
    print(f" Total Duplicate : {grand_total_dupe}")
    print(f" Total Rejected  : {grand_total_rejected}")
    print(f"=======================================================\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import folders of banana photos into dataset pipeline.")
    parser.add_argument("folder_path", type=str, help="Path to folder containing class directories")
    parser.add_argument("--bunch", dest="bunch_id", type=str, default=None, help="Optional bunch_id to assign")
    args = parser.parse_args()

    import_dataset(args.folder_path, bunch_id=args.bunch_id)
