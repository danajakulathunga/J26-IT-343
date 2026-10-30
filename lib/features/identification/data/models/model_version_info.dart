class ModelVersionInfo {
  final String id;
  final bool isActive;
  final String status;
  final String architecture;
  final String imageSize;
  final List<String> classNames;
  final double? testAccuracy;
  final double? macroF1;
  final String? createdAt;
  final bool pinned;
  final bool available;
  final bool isLegacyConfounded;

  ModelVersionInfo({
    required this.id,
    required this.isActive,
    required this.status,
    required this.architecture,
    required this.imageSize,
    required this.classNames,
    this.testAccuracy,
    this.macroF1,
    this.createdAt,
    required this.pinned,
    required this.available,
    this.isLegacyConfounded = false,
  });

  ModelVersionInfo copyWith({
    bool? isActive,
    String? status,
    bool? pinned,
    bool? isLegacyConfounded,
  }) {
    return ModelVersionInfo(
      id: id,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      architecture: architecture,
      imageSize: imageSize,
      classNames: classNames,
      testAccuracy: testAccuracy,
      macroF1: macroF1,
      createdAt: createdAt,
      pinned: pinned ?? this.pinned,
      available: available,
      isLegacyConfounded: isLegacyConfounded ?? this.isLegacyConfounded,
    );
  }

  factory ModelVersionInfo.fromJson(Map<String, dynamic> json) {
    String sizeStr = '224x224';
    if (json['image_size'] is List) {
      sizeStr = (json['image_size'] as List).join('x');
    } else if (json['image_size'] != null) {
      sizeStr = json['image_size'].toString();
    }

    return ModelVersionInfo(
      id: json['id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      status: json['status'] as String? ?? 'legacy',
      architecture: json['architecture'] as String? ?? 'unknown',
      imageSize: sizeStr,
      classNames: (json['class_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      testAccuracy: (json['test_accuracy'] as num?)?.toDouble(),
      macroF1: (json['macro_f1'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      isLegacyConfounded: json['is_legacy_confounded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_active': isActive,
      'status': status,
      'architecture': architecture,
      'image_size': imageSize,
      'class_names': classNames,
      'test_accuracy': testAccuracy,
      'macro_f1': macroF1,
      'created_at': createdAt,
      'pinned': pinned,
      'available': available,
      'is_legacy_confounded': isLegacyConfounded,
    };
  }
}
