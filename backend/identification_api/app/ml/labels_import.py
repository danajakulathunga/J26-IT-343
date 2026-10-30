"""
Labels Import CLI: Imports bunch_id and/or ripeness from a CSV file into data/labels.json.
Columns expected: path_or_sha16, bunch_id, ripeness
"""

import argparse
import csv
import hashlib
import os
import re
import sys
from typing import Any, Dict, List, Optional, Tuple

from app.ml.labels import (
    load_labels,
    save_labels,
    set_label,
    VALID_RIPENESS_STAGES,
    RIPENESS_STAGE_SET,
    BUNCH_ID_REGEX,
    DATA_DIR,
    RAW_INDEX_PATH,
)


def resolve_sha16(path_or_sha: str, labels: Dict[str, Any], raw_index: Dict[str, str]) -> Optional[str]:
    clean = path_or_sha.strip().replace("\\", "/")
    # 1. Exact 16-hex match in labels
    if clean in labels:
        return clean
    if len(clean) == 16 and re.match(r"^[0-9a-fA-F]{16}$", clean):
        return clean.lower()

    # 2. Check full sha64
    if len(clean) == 64 and re.match(r"^[0-9a-fA-F]{64}$", clean):
        short = clean[:16].lower()
        if short in labels:
            return short

    # 3. Check filename match (e.g. 01dcb88ea67d9b10.jpg)
    base = os.path.basename(clean)
    base_no_ext, _ = os.path.splitext(base)
    if base_no_ext in labels:
        return base_no_ext

    # 4. Check raw_index (relative path or filename match)
    for rel_path, full_sha in raw_index.items():
        if rel_path == clean or os.path.basename(rel_path) == base:
            return full_sha[:16]

    # 5. Check if path exists on disk and hash it
    if os.path.isfile(clean):
        try:
            with open(clean, "rb") as f:
                h = hashlib.sha256(f.read()).hexdigest()[:16]
                if h in labels:
                    return h
        except Exception:
            pass

    return None


def import_labels_from_csv(csv_path: str, dry_run: bool = False) -> Dict[str, Any]:
    if not os.path.isfile(csv_path):
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    labels = load_labels()
    raw_index = {}
    if os.path.exists(RAW_INDEX_PATH):
        try:
            import json
            with open(RAW_INDEX_PATH, "r", encoding="utf-8") as f:
                raw_index = json.load(f)
        except Exception:
            pass

    valid_rows = []
    invalid_rows = []

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        headers = [h.strip().lower() for h in (reader.fieldnames or [])]
        
        # Identify column names
        col_id = next((h for h in (reader.fieldnames or []) if h.strip().lower() in ("path_or_sha16", "sha16", "path", "id", "file")), None)
        col_bunch = next((h for h in (reader.fieldnames or []) if h.strip().lower() in ("bunch_id", "bunch", "proposed_bunch_id")), None)
        col_ripeness = next((h for h in (reader.fieldnames or []) if h.strip().lower() in ("ripeness", "stage")), None)

        if not col_id:
            raise ValueError(f"CSV missing required column 'path_or_sha16'. Found columns: {reader.fieldnames}")

        for row_idx, row in enumerate(reader, start=2):
            raw_id = (row.get(col_id) or "").strip()
            raw_bunch = (row.get(col_bunch) or "").strip() if col_bunch else None
            raw_ripeness = (row.get(col_ripeness) or "").strip() if col_ripeness else None

            if not raw_id:
                invalid_rows.append({"row": row_idx, "error": "Empty path_or_sha16", "data": row})
                continue

            sha16 = resolve_sha16(raw_id, labels, raw_index)
            if not sha16:
                invalid_rows.append({"row": row_idx, "error": f"Cannot resolve sha16 for '{raw_id}'", "data": row})
                continue

            # Validate bunch_id
            bunch_val = raw_bunch if raw_bunch else None
            if bunch_val is not None:
                if not BUNCH_ID_REGEX.match(bunch_val):
                    invalid_rows.append({
                        "row": row_idx,
                        "error": f"Invalid bunch_id '{bunch_val}' (must match ^[A-Za-z0-9-]+$)",
                        "data": row,
                    })
                    continue

            # Validate ripeness
            ripeness_val = raw_ripeness if raw_ripeness else None
            if ripeness_val is not None:
                if ripeness_val not in RIPENESS_STAGE_SET:
                    invalid_rows.append({
                        "row": row_idx,
                        "error": f"Invalid ripeness '{ripeness_val}' (must be one of {VALID_RIPENESS_STAGES})",
                        "data": row,
                    })
                    continue

            valid_rows.append({
                "sha16": sha16,
                "bunch_id": bunch_val,
                "ripeness": ripeness_val,
                "row_idx": row_idx,
            })

    print(f"\n[LABELS IMPORT] Found {len(valid_rows)} valid rows, {len(invalid_rows)} invalid rows.")
    if invalid_rows:
        print("[LABELS IMPORT] Sample invalid rows:")
        for inv in invalid_rows[:5]:
            print(f"  Row {inv['row']}: {inv['error']}")

    updated_count = 0
    if not dry_run:
        for r in valid_rows:
            sha16 = r["sha16"]
            existing = labels.get(sha16, {})
            new_variety = existing.get("variety", "Unknown")
            new_ripeness = r["ripeness"] if r["ripeness"] is not None else existing.get("ripeness")
            new_bunch = r["bunch_id"] if r["bunch_id"] is not None else existing.get("bunch_id")
            new_group = new_bunch if new_bunch else (existing.get("group_id") or f"legacy_{new_variety}")

            set_label(
                sha16,
                variety=new_variety,
                ripeness=new_ripeness,
                bunch_id=new_bunch,
                group_id=new_group,
                label_source="labels_import",
            )
            updated_count += 1
        print(f"[LABELS IMPORT] Successfully updated {updated_count} records in data/labels.json.")
    else:
        print(f"[LABELS IMPORT] DRY RUN completed: {len(valid_rows)} records would be updated.")

    return {
        "valid_count": len(valid_rows),
        "invalid_count": len(invalid_rows),
        "updated_count": updated_count,
        "dry_run": dry_run,
        "invalid_samples": invalid_rows[:10],
    }


def main():
    parser = argparse.ArgumentParser(description="Import bunch_id and ripeness metadata from CSV into labels.json.")
    parser.add_argument("csv_path", type=str, help="Path to CSV file with columns: path_or_sha16, bunch_id, ripeness")
    parser.add_argument("--dry-run", action="store_true", help="Validate without writing changes")
    args = parser.parse_args()

    import_labels_from_csv(args.csv_path, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
