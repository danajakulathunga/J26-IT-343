import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bananaguard_ai/models/scan_result.dart';

void main() {
  group('ScanResultModel Schema Deserialization Tests', () {
    test('Parses disease response with full schema and severity', () {
      const rawJson = '''
      {
        "scan_id": "test-disease-1234",
        "mode": "demo",
        "created_at": "2026-10-14T15:30:00Z",
        "variety": {
          "id": "ambul",
          "en": "Ambul",
          "si": "ඇඹුල්",
          "ta": "ஆம்புல்"
        },
        "condition": {
          "id": "anthracnose",
          "type": "Disease",
          "en": "Anthracnose",
          "si": "ඇන්ත්රැක්නෝස්",
          "description_si": "ප්‍රධාන පශ්චාත් අස්වනු රෝගයකි."
        },
        "condition_confidence": 0.92,
        "severity": {
          "level": "Moderate",
          "en": "Moderate",
          "si": "මධ්යස්ථ",
          "ta": "மிதமான"
        },
        "severity_confidence": 0.78,
        "severity_index": 54.0,
        "top_predictions": [
          {"id": "anthracnose", "en": "Anthracnose", "si": "ඇන්ත්රැක්නෝස්", "confidence": 0.92},
          {"id": "black_spots", "en": "Black Spots", "si": "කළු ලප", "confidence": 0.05}
        ],
        "cause_factors": [
          {"en": "High humidity", "si": "අධික ආර්ද්‍රතාවය", "ta": "அதிக ஈரப்பதம்"}
        ],
        "recommendations": [
          {"en": "Bunch bagging", "si": "කැන ආවරණය කිරීම", "ta": "குலை உறை"}
        ],
        "images": {
          "original_url": "/scans/test-disease-1234/original",
          "gradcam_url": "/scans/test-disease-1234/gradcam"
        },
        "highlight_box": {
          "x": 0.21,
          "y": 0.34,
          "w": 0.30,
          "h": 0.22
        },
        "quality_warnings": [],
        "low_confidence": false,
        "disclaimer": {
          "en": "Decision-support information only.",
          "si": "තීරණ සහායක තොරතුරු පමණි."
        }
      }
      ''';

      final Map<String, dynamic> map = jsonDecode(rawJson);
      final model = ScanResultModel.fromJson(map);

      expect(model.scanId, 'test-disease-1234');
      expect(model.mode, 'demo');
      expect(model.isDemo, true);
      expect(model.isHealthy, false);
      expect(model.condition.id, 'anthracnose');
      expect(model.condition.type, 'Disease');
      expect(model.condition.en, 'Anthracnose');
      expect(model.condition.si, 'ඇන්ත්රැක්නෝස්');
      expect(model.conditionConfidence, 0.92);
      expect(model.severity?.level, 'Moderate');
      expect(model.severityConfidence, 0.78);
      expect(model.severityIndex, 54.0);
      expect(model.topPredictions.length, 2);
      expect(model.causeFactors.length, 1);
      expect(model.recommendations.length, 1);
      expect(model.highlightBox?.w, 0.30);
      expect(model.lowConfidence, false);
    });

    test('Parses healthy banana response where severity and severityConfidence are null', () {
      const healthyJson = '''
      {
        "scan_id": "test-healthy-5678",
        "mode": "demo",
        "created_at": "2026-10-15T10:00:00Z",
        "variety": {
          "id": "cavendish",
          "en": "Cavendish",
          "si": "කැවෙන්ඩිෂ්",
          "ta": "கேவண்டிஷ்"
        },
        "condition": {
          "id": "healthy",
          "type": "Healthy",
          "en": "Healthy Banana",
          "si": "නිරෝගී කෙසෙල්",
          "description_si": "කිසිදු රෝග හෝ දෝෂ ලක්ෂණ නොමැත."
        },
        "condition_confidence": 0.98,
        "severity": null,
        "severity_confidence": null,
        "severity_index": 0.0,
        "top_predictions": [
          {"id": "healthy", "en": "Healthy Banana", "si": "නිරෝගී කෙසෙල්", "confidence": 0.98}
        ],
        "cause_factors": [],
        "recommendations": [
          {"en": "Continue optimal orchard maintenance", "si": "ප්‍රශස්ත වගා පාලන ක්‍රම අඛණ්ඩව කරගෙන යන්න."}
        ],
        "images": {
          "original_url": "/scans/test-healthy-5678/original",
          "gradcam_url": "/scans/test-healthy-5678/gradcam"
        },
        "highlight_box": null,
        "quality_warnings": [],
        "low_confidence": false,
        "disclaimer": {
          "en": "Decision-support information only.",
          "si": "තීරණ සහායක තොරතුරු පමණි."
        }
      }
      ''';

      final Map<String, dynamic> map = jsonDecode(healthyJson);
      final model = ScanResultModel.fromJson(map);

      expect(model.scanId, 'test-healthy-5678');
      expect(model.isHealthy, true);
      expect(model.severity, isNull);
      expect(model.severityConfidence, isNull);
      expect(model.severityIndex, 0.0);
      expect(model.highlightBox, isNull);
      expect(model.condition.type, 'Healthy');
    });

    test('Parses defect response with quality warnings and int numbers', () {
      const defectJson = '''
      {
        "scan_id": "test-defect-9012",
        "mode": "demo",
        "created_at": "2026-10-15T11:00:00Z",
        "variety": null,
        "condition": {
          "id": "peel_splitting",
          "type": "Defect",
          "en": "Peel Splitting",
          "si": "ලෙල්ල පැලීම"
        },
        "condition_confidence": 1,
        "severity": {
          "level": "Severe",
          "en": "Severe",
          "si": "දැඩි"
        },
        "severity_confidence": 1,
        "severity_index": 85,
        "top_predictions": [
          {"id": "peel_splitting", "en": "Peel Splitting", "si": "ලෙල්ල පැලීම", "confidence": 1}
        ],
        "cause_factors": [
          {"en": "Irregular watering", "si": "අක්‍රමවත් ජල සම්පාදනය"}
        ],
        "recommendations": [
          {"en": "Regulate irrigation intervals", "si": "ජල සම්පාදන කාල පරතරයන් පාලනය කරන්න"}
        ],
        "images": {
          "original_url": "/scans/test-defect-9012/original",
          "gradcam_url": "/scans/test-defect-9012/gradcam"
        },
        "highlight_box": {
          "x": 0.1,
          "y": 0.2,
          "w": 0.5,
          "h": 0.6
        },
        "quality_warnings": [
          {
            "code": "low_resolution",
            "en": "Low resolution image",
            "si": "ඡායාරූපයේ විභේදනය අඩුයි"
          }
        ],
        "low_confidence": false,
        "disclaimer": {
          "en": "Decision-support information only.",
          "si": "තීරණ සහායක තොරතුරු පමණි."
        }
      }
      ''';

      final Map<String, dynamic> map = jsonDecode(defectJson);
      final model = ScanResultModel.fromJson(map);

      expect(model.scanId, 'test-defect-9012');
      expect(model.isHealthy, false);
      expect(model.variety, isNull);
      expect(model.condition.id, 'peel_splitting');
      expect(model.conditionConfidence, 1.0);
      expect(model.severity?.level, 'Severe');
      expect(model.severityConfidence, 1.0);
      expect(model.severityIndex, 85.0);
      expect(model.qualityWarnings.length, 1);
      expect(model.qualityWarnings.first.code, 'low_resolution');
    });

    test('Gracefully handles missing or malformed fields without throwing', () {
      final minimalJson = {
        'scan_id': 'minimal-id',
        'condition_confidence': 0.85,
      };

      final model = ScanResultModel.fromJson(minimalJson);
      expect(model.scanId, 'minimal-id');
      expect(model.condition.id, 'unknown');
      expect(model.images.originalUrl, '');
      expect(model.disclaimer.en, isNotEmpty);
      expect(model.severity, isNull);
      expect(model.topPredictions, isEmpty);
    });
  });
}
