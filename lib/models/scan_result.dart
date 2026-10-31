import 'package:bananaguard_ai/models/condition_info.dart';

class ConditionOutputModel {
  final String id;
  final String type; // Healthy, Disease, Defect
  final String en;
  final String si;
  final String? ta;
  final String? descriptionSi;
  final String? descriptionTa;

  ConditionOutputModel({
    required this.id,
    required this.type,
    required this.en,
    required this.si,
    this.ta,
    this.descriptionSi,
    this.descriptionTa,
  });

  factory ConditionOutputModel.fromJson(Map<String, dynamic> json) {
    return ConditionOutputModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'Defect',
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
      ta: json['ta'] as String?,
      descriptionSi: json['description_si'] as String?,
      descriptionTa: json['description_ta'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'en': en,
    'si': si,
    'ta': ta,
    'description_si': descriptionSi,
    'description_ta': descriptionTa,
  };

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : en;
    if (lang == 'ta') {
      if (ta != null && ta!.trim().isNotEmpty) return ta!;
      final fallback = ConditionInfoModel.fallbackNamesTa[id.toLowerCase()];
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return en.trim().isNotEmpty ? en : si;
    }
    return en.trim().isNotEmpty ? en : si;
  }

  String getDescription(String lang) {
    if (lang == 'si') return descriptionSi ?? '';
    if (lang == 'ta') {
      if (descriptionTa != null && descriptionTa!.trim().isNotEmpty) return descriptionTa!;
      final fallback = ConditionInfoModel.fallbackDescriptionsTa[id.toLowerCase()];
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return descriptionSi ?? '';
    }
    final fallback = ConditionInfoModel.fallbackDescriptionsEn[id.toLowerCase()];
    return fallback ?? '';
  }
}

class SeverityOutputModel {
  final String level; // Mild, Moderate, Severe
  final String en;
  final String si;
  final String? ta;

  SeverityOutputModel({
    required this.level,
    required this.en,
    required this.si,
    this.ta,
  });

  factory SeverityOutputModel.fromJson(Map<String, dynamic> json) {
    return SeverityOutputModel(
      level: json['level'] as String? ?? 'Mild',
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
      ta: json['ta'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'en': en,
    'si': si,
    'ta': ta,
  };

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : (level.isNotEmpty ? level : en);
    if (lang == 'ta') {
      if (ta != null && ta!.trim().isNotEmpty) return ta!;
      if (level.toLowerCase() == 'severe') return 'கடுமையான';
      if (level.toLowerCase() == 'moderate') return 'மிதமான';
      if (level.toLowerCase() == 'mild') return 'லேசான';
      return level;
    }
    return level.isNotEmpty ? level : en;
  }
}

class TopPredictionModel {
  final String id;
  final String en;
  final String si;
  final String? ta;
  final double confidence;

  TopPredictionModel({
    required this.id,
    required this.en,
    required this.si,
    this.ta,
    required this.confidence,
  });

  factory TopPredictionModel.fromJson(Map<String, dynamic> json) {
    return TopPredictionModel(
      id: json['id'] as String? ?? '',
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
      ta: json['ta'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'en': en,
    'si': si,
    'ta': ta,
    'confidence': confidence,
  };

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : en;
    if (lang == 'ta') {
      if (ta != null && ta!.trim().isNotEmpty) return ta!;
      final fallback = ConditionInfoModel.fallbackNamesTa[id.toLowerCase()];
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return en.trim().isNotEmpty ? en : si;
    }
    return en.trim().isNotEmpty ? en : si;
  }
}

class ImagesOutputModel {
  final String originalUrl;
  final String gradcamUrl;

  ImagesOutputModel({required this.originalUrl, required this.gradcamUrl});

  factory ImagesOutputModel.fromJson(Map<String, dynamic> json) {
    return ImagesOutputModel(
      originalUrl: json['original_url'] as String? ?? '',
      gradcamUrl: json['gradcam_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'original_url': originalUrl,
    'gradcam_url': gradcamUrl,
  };
}

class HighlightBoxModel {
  final double x;
  final double y;
  final double w;
  final double h;

  HighlightBoxModel({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory HighlightBoxModel.fromJson(Map<String, dynamic> json) {
    return HighlightBoxModel(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 0.0,
      h: (json['h'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
}

class QualityWarningModel {
  final String code;
  final String en;
  final String si;

  QualityWarningModel({required this.code, required this.en, required this.si});

  factory QualityWarningModel.fromJson(Map<String, dynamic> json) {
    return QualityWarningModel(
      code: json['code'] as String? ?? '',
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'en': en, 'si': si};

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : en;
    return en.trim().isNotEmpty ? en : si;
  }
}

class ScanResultModel {
  final String scanId;
  final String mode; // demo | real
  final String createdAt;
  final VarietyModel? variety;
  final ConditionOutputModel condition;
  final double conditionConfidence;
  final SeverityOutputModel? severity;
  final double? severityConfidence;
  final double severityIndex;
  final List<TopPredictionModel> topPredictions;
  final List<LocalizedTextModel> causeFactors;
  final List<LocalizedTextModel> recommendations;
  final ImagesOutputModel images;
  final HighlightBoxModel? highlightBox;
  final List<QualityWarningModel> qualityWarnings;
  final bool lowConfidence;
  final LocalizedTextModel disclaimer;

  ScanResultModel({
    required this.scanId,
    required this.mode,
    required this.createdAt,
    this.variety,
    required this.condition,
    required this.conditionConfidence,
    this.severity,
    this.severityConfidence,
    required this.severityIndex,
    required this.topPredictions,
    required this.causeFactors,
    required this.recommendations,
    required this.images,
    this.highlightBox,
    required this.qualityWarnings,
    required this.lowConfidence,
    required this.disclaimer,
  });

  bool get isDemo => mode.toLowerCase() == 'demo';
  bool get isHealthy => condition.id.toLowerCase() == 'healthy';

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    // Condition
    ConditionOutputModel parsedCondition;
    if (json['condition'] is Map) {
      parsedCondition = ConditionOutputModel.fromJson(
        Map<String, dynamic>.from(json['condition'] as Map),
      );
    } else {
      parsedCondition = ConditionOutputModel(
        id: 'unknown',
        type: 'Defect',
        en: 'Unknown',
        si: 'නොදනී',
      );
    }

    // Variety
    VarietyModel? parsedVariety;
    if (json['variety'] is Map) {
      parsedVariety = VarietyModel.fromJson(
        Map<String, dynamic>.from(json['variety'] as Map),
      );
    }

    // Severity
    SeverityOutputModel? parsedSeverity;
    if (json['severity'] is Map) {
      parsedSeverity = SeverityOutputModel.fromJson(
        Map<String, dynamic>.from(json['severity'] as Map),
      );
    }

    // Images
    ImagesOutputModel parsedImages;
    if (json['images'] is Map) {
      parsedImages = ImagesOutputModel.fromJson(
        Map<String, dynamic>.from(json['images'] as Map),
      );
    } else {
      parsedImages = ImagesOutputModel(originalUrl: '', gradcamUrl: '');
    }

    // Highlight box
    HighlightBoxModel? parsedHighlightBox;
    if (json['highlight_box'] is Map) {
      parsedHighlightBox = HighlightBoxModel.fromJson(
        Map<String, dynamic>.from(json['highlight_box'] as Map),
      );
    }

    // Disclaimer
    LocalizedTextModel parsedDisclaimer;
    if (json['disclaimer'] is Map) {
      parsedDisclaimer = LocalizedTextModel.fromJson(
        Map<String, dynamic>.from(json['disclaimer'] as Map),
      );
    } else {
      parsedDisclaimer = LocalizedTextModel(
        en: 'Decision-support information only.',
        si: 'තීරණ සහායක තොරතුරු පමණි.',
      );
    }

    return ScanResultModel(
      scanId: json['scan_id']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'demo',
      createdAt: json['created_at']?.toString() ?? '',
      variety: parsedVariety,
      condition: parsedCondition,
      conditionConfidence: (json['condition_confidence'] as num?)?.toDouble() ?? 0.0,
      severity: parsedSeverity,
      severityConfidence: (json['severity_confidence'] as num?)?.toDouble(),
      severityIndex: (json['severity_index'] as num?)?.toDouble() ?? 0.0,
      topPredictions: (json['top_predictions'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => TopPredictionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      causeFactors: (json['cause_factors'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => LocalizedTextModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => LocalizedTextModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      images: parsedImages,
      highlightBox: parsedHighlightBox,
      qualityWarnings: (json['quality_warnings'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => QualityWarningModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lowConfidence: json['low_confidence'] as bool? ?? false,
      disclaimer: parsedDisclaimer,
    );
  }

  Map<String, dynamic> toJson() => {
    'scan_id': scanId,
    'mode': mode,
    'created_at': createdAt,
    'variety': variety?.toJson(),
    'condition': condition.toJson(),
    'condition_confidence': conditionConfidence,
    'severity': severity?.toJson(),
    'severity_confidence': severityConfidence,
    'severity_index': severityIndex,
    'top_predictions': topPredictions.map((e) => e.toJson()).toList(),
    'cause_factors': causeFactors.map((e) => e.toJson()).toList(),
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'images': images.toJson(),
    'highlight_box': highlightBox?.toJson(),
    'quality_warnings': qualityWarnings.map((e) => e.toJson()).toList(),
    'low_confidence': lowConfidence,
    'disclaimer': disclaimer.toJson(),
  };
}
