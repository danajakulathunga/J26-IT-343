class Top3Candidate {
  final String rawClass;
  final double confidence;

  Top3Candidate({required this.rawClass, required this.confidence});

  factory Top3Candidate.fromJson(Map<String, dynamic> json) {
    return Top3Candidate(
      rawClass: json['raw_class'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'raw_class': rawClass,
    'confidence': confidence,
  };
}

class VarietyResult {
  final String fruitType;
  final String variety;
  final double confidence;
  final String? modelVersion;
  final String? imageSize;
  final String? architecture;
  final List<Top3Candidate>? top3;
  final bool? lowConfidence;

  VarietyResult({
    required this.fruitType,
    required this.variety,
    required this.confidence,
    this.modelVersion,
    this.imageSize,
    this.architecture,
    this.top3,
    this.lowConfidence,
  });

  factory VarietyResult.fromJson(Map<String, dynamic> json) {
    String? parsedSize;
    if (json['image_size'] is List) {
      parsedSize = (json['image_size'] as List).join('x');
    } else if (json['image_size'] != null) {
      parsedSize = json['image_size'].toString();
    }

    List<Top3Candidate>? parsedTop3;
    if (json['top3'] is List) {
      parsedTop3 = (json['top3'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => Top3Candidate.fromJson(e))
          .toList();
    }

    return VarietyResult(
      fruitType: json['fruit_type'] as String? ?? '',
      variety: json['variety'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      modelVersion: json['model_version'] as String?,
      imageSize: parsedSize,
      architecture: json['architecture'] as String?,
      top3: parsedTop3,
      lowConfidence: json['low_confidence'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'fruit_type': fruitType,
      'variety': variety,
      'confidence': confidence,
    };
    if (modelVersion != null) map['model_version'] = modelVersion;
    if (imageSize != null) map['image_size'] = imageSize;
    if (architecture != null) map['architecture'] = architecture;
    if (top3 != null) map['top3'] = top3!.map((e) => e.toJson()).toList();
    if (lowConfidence != null) map['low_confidence'] = lowConfidence;
    return map;
  }
}
