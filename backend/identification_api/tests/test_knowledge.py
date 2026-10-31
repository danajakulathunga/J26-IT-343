import json
import os
import pytest
from app.services.knowledge import knowledge_service, DATA_DIR


def test_knowledge_base_integrity():
    kb_path = os.path.join(DATA_DIR, "knowledge_base.json")
    labels_path = os.path.join(DATA_DIR, "labels.json")

    with open(kb_path, "r", encoding="utf-8") as f:
        kb_data = json.load(f)

    with open(labels_path, "r", encoding="utf-8") as f:
        labels_data = json.load(f)

    # 1. Assert exactly 17 entries
    assert len(kb_data) == 17, f"Expected 17 entries, found {len(kb_data)}"
    assert len(labels_data) == 17, f"Expected 17 labels, found {len(labels_data)}"

    # 2. Assert IDs match labels.json ordering
    kb_ids = [entry["id"] for entry in kb_data]
    label_names = [label["name"] for label in labels_data]
    assert kb_ids == label_names, "Knowledge base IDs must match labels.json names in exact order"

    # 3. Assert each entry has exactly 3 cause factors and 3 recommendations with non-empty en and si
    for entry in kb_data:
        cond_id = entry["id"]

        # Cause factors check
        assert "cause_factors" in entry, f"Missing cause_factors for {cond_id}"
        causes = entry["cause_factors"]
        assert len(causes) == 3, f"Expected exactly 3 cause factors for {cond_id}, got {len(causes)}"
        for idx, cause in enumerate(causes):
            assert "en" in cause and cause["en"].strip(), f"Empty 'en' in cause #{idx+1} for {cond_id}"
            assert "si" in cause and cause["si"].strip(), f"Empty 'si' in cause #{idx+1} for {cond_id}"

        # Recommendations check
        assert "recommendations" in entry, f"Missing recommendations for {cond_id}"
        recs = entry["recommendations"]
        assert len(recs) == 3, f"Expected exactly 3 recommendations for {cond_id}, got {len(recs)}"
        for idx, rec in enumerate(recs):
            assert "en" in rec and rec["en"].strip(), f"Empty 'en' in recommendation #{idx+1} for {cond_id}"
            assert "si" in rec and rec["si"].strip(), f"Empty 'si' in recommendation #{idx+1} for {cond_id}"
            assert "ta" in rec and rec["ta"].strip(), f"Empty 'ta' in recommendation #{idx+1} for {cond_id}"

        # Severity levels check
        assert "severity_levels" in entry, f"Missing severity_levels for {cond_id}"
        sev_levels = entry["severity_levels"]
        for sev_key in ["mild", "moderate", "severe"]:
            assert sev_key in sev_levels, f"Missing severity level {sev_key} in {cond_id}"
            s_data = sev_levels[sev_key]
            assert "cause_factors" in s_data and len(s_data["cause_factors"]) == 3, f"Expected 3 causes in {cond_id}.{sev_key}"
            assert "recommendations" in s_data and len(s_data["recommendations"]) == 3, f"Expected 3 recs in {cond_id}.{sev_key}"
            for c in s_data["cause_factors"]:
                assert c["en"].strip() and c["si"].strip() and c["ta"].strip(), f"Missing en/si/ta in causes for {cond_id}.{sev_key}"
            for r in s_data["recommendations"]:
                assert r["en"].strip() and r["si"].strip() and r["ta"].strip(), f"Missing en/si/ta in recs for {cond_id}.{sev_key}"

