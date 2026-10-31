import json
import os
from typing import Dict, List, Optional
from app.schemas.meta import LocalizedText, VarietyResponse, ConditionDetailResponse, SeverityContent

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

DISCLAIMER = LocalizedText(
    en="Decision-support information only. Consult an agricultural expert before applying treatments.",
    si="තීරණ සහායක තොරතුරු පමණි. ප්‍රතිකාර යෙදීමට පෙර කෘෂිකාර්මික විශේෂඥයෙකුගෙන් උපදෙස් ලබා ගන්න.",
    ta="முடிவு ஆதரவு தகவல் மட்டுமே. சிகிச்சைகளைப் பயன்படுத்துவதற்கு முன் ஒரு விவசாய நிபுணரை அணுகவும்."
)


class KnowledgeService:
    def __init__(self):
        self._labels: List[Dict] = []
        self._varieties: List[Dict] = []
        self._knowledge_base: List[Dict] = []
        self._knowledge_map: Dict[str, Dict] = {}
        self._variety_map: Dict[str, Dict] = {}
        self._load_data()

    def _load_data(self):
        labels_path = os.path.join(DATA_DIR, "labels.json")
        varieties_path = os.path.join(DATA_DIR, "varieties.json")
        kb_path = os.path.join(DATA_DIR, "knowledge_base.json")

        with open(labels_path, "r", encoding="utf-8") as f:
            self._labels = json.load(f)

        with open(varieties_path, "r", encoding="utf-8") as f:
            self._varieties = json.load(f)
            self._variety_map = {v["id"].lower(): v for v in self._varieties}

        with open(kb_path, "r", encoding="utf-8") as f:
            self._knowledge_base = json.load(f)
            self._knowledge_map = {entry["id"]: entry for entry in self._knowledge_base}

    def get_labels(self) -> List[Dict]:
        return self._labels

    def get_varieties(self) -> List[VarietyResponse]:
        return [VarietyResponse(**v) for v in self._varieties]

    def get_variety_by_id(self, variety_id: Optional[str]) -> Optional[VarietyResponse]:
        if not variety_id:
            return None
        data = self._variety_map.get(variety_id.lower().strip())
        return VarietyResponse(**data) if data else None

    def get_condition_by_index(self, index: int) -> Optional[Dict]:
        if 0 <= index < len(self._labels):
            label_entry = self._labels[index]
            cond_id = label_entry["name"]
            kb_entry = self._knowledge_map.get(cond_id)
            if kb_entry:
                merged = dict(kb_entry)
                merged["type"] = label_entry["type"]
                return merged
        return None

    def get_condition_by_id(self, condition_id: str) -> Optional[Dict]:
        clean_id = condition_id.lower().strip()
        kb_entry = self._knowledge_map.get(clean_id)
        if not kb_entry:
            return None
        # find matching type from labels
        cond_type = "Defect"
        for lbl in self._labels:
            if lbl["name"] == clean_id:
                cond_type = lbl["type"]
                break
        merged = dict(kb_entry)
        merged["type"] = cond_type
        return merged

    def get_severity_content(self, condition_id: str, severity_level: Optional[str] = None) -> tuple[List[Dict], List[Dict]]:
        clean_id = condition_id.lower().strip()
        kb_entry = self._knowledge_map.get(clean_id)
        if not kb_entry:
            return [], []

        sev_levels = kb_entry.get("severity_levels")
        if sev_levels:
            target_key = severity_level.lower().strip() if severity_level else "mild"
            if target_key in sev_levels:
                data = sev_levels[target_key]
                return data.get("cause_factors", []), data.get("recommendations", [])
            elif "mild" in sev_levels:
                data = sev_levels["mild"]
                return data.get("cause_factors", []), data.get("recommendations", [])
            elif "healthy" in sev_levels:
                data = sev_levels["healthy"]
                return data.get("cause_factors", []), data.get("recommendations", [])

        return kb_entry.get("cause_factors", []), kb_entry.get("recommendations", [])

    def get_all_conditions(self) -> List[ConditionDetailResponse]:
        results = []
        for lbl in self._labels:
            cond_id = lbl["name"]
            kb = self._knowledge_map.get(cond_id, {})

            parsed_sev_levels = None
            if "severity_levels" in kb and isinstance(kb["severity_levels"], dict):
                parsed_sev_levels = {}
                for lvl, data in kb["severity_levels"].items():
                    parsed_sev_levels[lvl] = SeverityContent(
                        cause_factors=[LocalizedText(**item) for item in data.get("cause_factors", [])],
                        recommendations=[LocalizedText(**item) for item in data.get("recommendations", [])]
                    )

            results.append(
                ConditionDetailResponse(
                    id=cond_id,
                    label_id=lbl["id"],
                    name_en=kb.get("name_en", cond_id.replace("_", " ").title()),
                    name_si=kb.get("name_si", ""),
                    name_ta=kb.get("name_ta", ""),
                    type=lbl["type"],
                    description_si=kb.get("description_si", ""),
                    description_ta=kb.get("description_ta", ""),
                    cause_factors=[LocalizedText(**item) for item in kb.get("cause_factors", [])],
                    recommendations=[LocalizedText(**item) for item in kb.get("recommendations", [])],
                    severity_levels=parsed_sev_levels
                )
            )
        return results


knowledge_service = KnowledgeService()

