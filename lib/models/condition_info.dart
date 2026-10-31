import '../data/knowledge_base_data.dart';
import '../data/default_conditions.dart';

class LocalizedTextModel {
  final String en;

  final String si;
  final String? ta;

  LocalizedTextModel({
    required this.en,
    required this.si,
    this.ta,
  });

  factory LocalizedTextModel.fromJson(Map<String, dynamic> json) {
    return LocalizedTextModel(
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
      ta: json['ta'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'en': en, 'si': si, 'ta': ta};

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : en;
    if (lang == 'ta') return (ta != null && ta!.trim().isNotEmpty) ? ta! : (si.trim().isNotEmpty ? si : en);
    return en.trim().isNotEmpty ? en : si;
  }
}

class VarietyModel {
  final String id;
  final String en;
  final String si;
  final String? ta;

  VarietyModel({
    required this.id,
    required this.en,
    required this.si,
    this.ta,
  });

  factory VarietyModel.fromJson(Map<String, dynamic> json) {
    return VarietyModel(
      id: json['id'] as String? ?? '',
      en: json['en'] as String? ?? '',
      si: json['si'] as String? ?? '',
      ta: json['ta'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'en': en, 'si': si, 'ta': ta};

  String getLocalized(String lang) {
    if (lang == 'si') return si.trim().isNotEmpty ? si : en;
    if (lang == 'ta') return (ta != null && ta!.trim().isNotEmpty) ? ta! : (si.trim().isNotEmpty ? si : en);
    return en.trim().isNotEmpty ? en : si;
  }

  static List<VarietyModel> get defaultVarieties => [
    VarietyModel(id: 'cavendish', en: 'Cavendish', si: 'කැවෙන්ඩිෂ්', ta: 'கேவண்டிஷ்'),
    VarietyModel(id: 'ambul', en: 'Ambul', si: 'ඇඹුල්', ta: 'ஆம்புல்'),
    VarietyModel(id: 'kolikuttu', en: 'Kolikuttu', si: 'කෝලිකුට්ටු', ta: 'கோலிக்குட்டு'),
    VarietyModel(id: 'seeni', en: 'Seeni', si: 'සීනි', ta: 'சீனி வாழை'),
    VarietyModel(id: 'anamalu', en: 'Anamalu', si: 'ඇනමළු', ta: 'ஆனமாலு'),
    VarietyModel(id: 'rath_kesel', en: 'Rath Kesel', si: 'රත් කෙසෙල්', ta: 'செவ்வாழை'),
    VarietyModel(id: 'suwandel', en: 'Suwandel', si: 'සුවඳැල්', ta: 'சுவந்தேல்'),
    VarietyModel(id: 'puwalu', en: 'Puwalu', si: 'පුවාලු', ta: 'புவாலு'),
  ];
}

class SeverityContentModel {
  final List<LocalizedTextModel> causeFactors;
  final List<LocalizedTextModel> recommendations;

  SeverityContentModel({
    required this.causeFactors,
    required this.recommendations,
  });

  factory SeverityContentModel.fromJson(Map<String, dynamic> json) {
    return SeverityContentModel(
      causeFactors: (json['cause_factors'] as List<dynamic>? ?? [])
          .map((e) => LocalizedTextModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((e) => LocalizedTextModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'cause_factors': causeFactors.map((e) => e.toJson()).toList(),
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
  };
}

class ConditionInfoModel {
  final String id;
  final int labelId;
  final String nameEn;
  final String nameSi;
  final String? nameTa;
  final String type; // Healthy, Disease, Defect
  final String descriptionSi;
  final String? descriptionTa;
  final List<LocalizedTextModel> causeFactors;
  final List<LocalizedTextModel> recommendations;
  final Map<String, SeverityContentModel>? severityLevels;

  ConditionInfoModel({
    required this.id,
    required this.labelId,
    required this.nameEn,
    required this.nameSi,
    this.nameTa,
    required this.type,
    required this.descriptionSi,
    this.descriptionTa,
    required this.causeFactors,
    required this.recommendations,
    this.severityLevels,
  });

  factory ConditionInfoModel.fromJson(Map<String, dynamic> json) {
    Map<String, SeverityContentModel>? parsedSeverityLevels;
    if (json['severity_levels'] != null && json['severity_levels'] is Map) {
      final rawMap = json['severity_levels'] as Map<String, dynamic>;
      parsedSeverityLevels = rawMap.map(
        (k, v) => MapEntry(k.toLowerCase(), SeverityContentModel.fromJson(v as Map<String, dynamic>)),
      );
    }

    return ConditionInfoModel(
      id: json['id'] as String? ?? '',
      labelId: json['label_id'] as int? ?? 0,
      nameEn: json['name_en'] as String? ?? '',
      nameSi: json['name_si'] as String? ?? '',
      nameTa: json['name_ta'] as String? ?? json['ta'] as String?,
      type: json['type'] as String? ?? 'Disease',
      descriptionSi: json['description_si'] as String? ?? '',
      descriptionTa: json['description_ta'] as String?,
      causeFactors: (json['cause_factors'] as List<dynamic>? ?? [])
          .map((e) => LocalizedTextModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((e) => LocalizedTextModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      severityLevels: parsedSeverityLevels,
    );
  }

  List<LocalizedTextModel> getCauseFactorsForSeverity(String? severity) {
    final key = severity?.toLowerCase() ?? 'mild';
    if (severityLevels != null && severityLevels!.containsKey(key)) {
      return severityLevels![key]!.causeFactors;
    }
    final fallbackMap = KnowledgeBaseData.fallbackSeverityLevels[id.toLowerCase()];
    if (fallbackMap != null && fallbackMap.containsKey(key)) {
      return fallbackMap[key]!.causeFactors;
    }
    return causeFactors;
  }

  List<LocalizedTextModel> getRecommendationsForSeverity(String? severity) {
    final key = severity?.toLowerCase() ?? 'mild';
    if (severityLevels != null && severityLevels!.containsKey(key)) {
      return severityLevels![key]!.recommendations;
    }
    final fallbackMap = KnowledgeBaseData.fallbackSeverityLevels[id.toLowerCase()];
    if (fallbackMap != null && fallbackMap.containsKey(key)) {
      return fallbackMap[key]!.recommendations;
    }
    return recommendations;
  }


  static List<ConditionInfoModel> get defaultConditions => defaultConditionList;

  static ConditionInfoModel? getConditionById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final clean = id.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    return defaultConditionList.cast<ConditionInfoModel?>().firstWhere(
      (c) => c?.id.toLowerCase() == clean,
      orElse: () => null,
    );
  }

  static const Map<String, String> fallbackNamesTa = {
    'healthy': 'ஆரோக்கியமானது',
    'anthracnose': 'அந்திரக்னோஸ்',
    'crown_rot': 'முடி அழுகல்',
    'finger_rot': 'விரல் அழுகல்',
    'black_end_rot': 'முனை அழுகல் நோய்',
    'bacterial_soft_rot': 'பாக்டீரியா மென் அழுகல்',
    'fusarium_rot': 'பியூசாரியம் அழுகல்',
    'bruising': 'நசுங்குதல்',
    'physical_damage': 'இயந்திர சேதம்',
    'black_spots': 'கருப்பு புள்ளிகள்',
    'scarring': 'தழும்புகள்',
    'skin_splitting': 'தோல் வெடிப்பு',
    'insect_damage': 'பூச்சி சேதம்',
    'deformation': 'வடிவ மாற்றம்',
    'wrinkling': 'சுருங்குதல்',
    'sunburn': 'சூரியக் காயம்',
    'sap_latex_stain': 'பால் கறைகள்',
  };

  static const Map<String, String> fallbackDescriptionsTa = {
    'healthy': 'எந்தவித நோயோ அல்லது சேதமோ இல்லாத உயர்தர ஆரோக்கியமான வாழைப் பழம்.',
    'anthracnose': 'Colletotrichum musae பூஞ்சையால் பழத்தோலில் ஏற்படும் கரும்புள்ளி மற்றும் அழுகல் நோய்.',
    'crown_rot': 'வாழைச் சீப்பு வெட்டப்பட்ட பகுதியில் பூஞ்சைத் தொற்றினால் ஏற்படும் கருமை மற்றும் மென் அழுகல்.',
    'finger_rot': 'தனித்தனி வாழை விரல் பழங்களில் ஏற்படும் கருமை நிற பூஞ்சை அழுகல்.',
    'black_end_rot': 'பூ அமைந்த நுனிப்பகுதியில் பூஞ்சைத் தொற்றால் உருவாகும் காய்ந்த கருப்பு அழுகல்.',
    'bacterial_soft_rot': 'Dickeya / Pectobacterium பாக்டீரியாவால் ஏற்படும் துர்நாற்றமுடைய நீர்ம மென் அழுகல்.',
    'fusarium_rot': 'Fusarium பூஞ்சையால் பழத்தோல் மீது வெள்ளை நிற பூஞ்சை படலத்துடன் தோன்றும் அழுகல்.',
    'bruising': 'கையாளுதல் மற்றும் போக்குவரத்தின் போது ஏற்படும் அழுத்தத்தால் திசுக்கள் நசுங்கி கறுத்தல்.',
    'physical_damage': 'வெட்டுகள், கீறல்கள் அல்லது மோதல்களால் தோலில் ஏற்படும் இயந்திர சேதம்.',
    'black_spots': 'சுற்றுச்சூழல் அல்லது சிறிய பூஞ்சைத் தொற்றுகளால் தோலின் மேல் தோன்றும் சிறு கரும்புள்ளிகள்.',
    'scarring': 'இளம் பருவத்தில் பூச்சிகள் அல்லது உராய்வுகளால் தோலில் உருவாகும் தழும்புகள்.',
    'skin_splitting': 'அதிக ஈரப்பதம் அல்லது விரைவாகப் பழுப்பதால் தோலில் ஏற்படும் நீள வெடிப்புகள்.',
    'insect_damage': 'பூச்சிகள் சாற்றை உறிஞ்சுவதால் பழத்தின் தோலில் ஏற்படும் சேதங்கள்.',
    'deformation': 'மகரந்தச் சேர்க்கை அல்லது ஊட்டச்சத்துக் குறைபாட்டால் ஏற்படும் அசாதாரண பழ வடிவம்.',
    'wrinkling': 'நீர் இழப்பு அல்லது வறட்சியால் பழத்தோல் வறண்டு சுருங்குதல்.',
    'sunburn': 'நேரடி சூரிய ஒளியால் பழத்தோல் பழுப்பு அல்லது கருப்பாகக் கருகிப்போதல்.',
    'sap_latex_stain': 'அறுவடையின் போது வடியும் வாழைப்பால் தோலில் பட்டு உருவாகும் கருப்பு கறைகள்.',
  };

  static const Map<String, String> fallbackDescriptionsEn = {
    'healthy': 'A high-quality healthy banana fruit with no signs of disease or physical damage.',
    'anthracnose': 'A major postharvest disease caused by Colletotrichum musae that produces sunken dark lesions on the banana peel.',
    'crown_rot': 'Darkening, decay, and softening caused by a fungal complex at the cut crown of the banana hand.',
    'finger_rot': 'A fungal decay that starts at the stem or tip of an individual banana finger and spreads toward the pulp.',
    'black_end_rot': 'Blackening, drying, or decay of the blossom end of the banana fruit.',
    'bacterial_soft_rot': 'A soft, watery decay with an unpleasant odor caused by Dickeya or Pectobacterium bacteria.',
    'fusarium_rot': 'Tissue decay with white or pink mold caused by Fusarium fungal species.',
    'bruising': 'Darkening of the internal peel tissue caused by pressure, impacts, or vibration.',
    'physical_damage': 'Cuts or scratches on the banana peel caused by sharp tools, fingernails, or impacts.',
    'black_spots': 'Small scattered black spots appearing on the surface of the peel.',
    'scarring': 'Silver or brown dry scars on the peel caused by leaf rubbing or insect scratches.',
    'skin_splitting': 'Lengthwise splitting of the banana peel caused by rapid pulp expansion.',
    'insect_damage': 'Damage caused by thrips, beetles, or caterpillars biting or puncturing the peel.',
    'deformation': 'An abnormal fruit shape caused by twisting, fused fingers, or stunted growth.',
    'wrinkling': 'Drying, wrinkling, and wilting of the banana peel caused by water loss or drought.',
    'sunburn': 'Browning or bleaching and scorching of the banana peel caused by intense direct sunlight.',
    'sap_latex_stain': 'Black marks on the peel caused by latex released during harvesting and cutting.',
  };

  String getName(String lang) {
    if (lang == 'si') return nameSi.trim().isNotEmpty ? nameSi : nameEn;
    if (lang == 'ta') {
      if (nameTa != null && nameTa!.trim().isNotEmpty) return nameTa!;
      final fallback = fallbackNamesTa[id.toLowerCase()];
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return nameEn;
    }
    return nameEn;
  }

  String getDescription(String lang) {
    if (lang == 'si') return descriptionSi;
    if (lang == 'ta') {
      if (descriptionTa != null && descriptionTa!.trim().isNotEmpty) return descriptionTa!;
      final fallback = fallbackDescriptionsTa[id.toLowerCase()];
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return descriptionSi;
    }
    return fallbackDescriptionsEn[id.toLowerCase()] ?? descriptionSi;
  }

  String getTypeLocalized(String lang) {
    if (lang == 'si') {
      if (type.toLowerCase() == 'disease') return 'රෝගය';
      if (type.toLowerCase() == 'defect') return 'දෝෂය';
      if (type.toLowerCase() == 'healthy') return 'නිරෝගී';
      return type;
    }
    if (lang == 'ta') {
      if (type.toLowerCase() == 'disease') return 'நோய்';
      if (type.toLowerCase() == 'defect') return 'குறைபாடு';
      if (type.toLowerCase() == 'healthy') return 'ஆரோக்கியமானது';
      return type;
    }
    return type;
  }
}
