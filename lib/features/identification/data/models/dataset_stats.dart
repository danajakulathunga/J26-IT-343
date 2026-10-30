class ClassImageCount {
  final int rawCount;
  final int processedCount;
  final int unsyncedCount;
  final int duplicatesSkipped;

  ClassImageCount({
    required this.rawCount,
    required this.processedCount,
    this.unsyncedCount = 0,
    this.duplicatesSkipped = 0,
  });

  factory ClassImageCount.fromJson(Map<String, dynamic> json) {
    final raw = json['raw_count'] as int? ?? 0;
    final proc = json['processed_count'] as int? ?? 0;
    final unsynced = json['unsynced_count'] as int? ?? (raw > proc ? raw - proc : 0);
    final duplicates = json['duplicates_skipped'] as int? ?? (json['duplicate'] as int? ?? 0);
    return ClassImageCount(
      rawCount: raw,
      processedCount: proc,
      unsyncedCount: unsynced,
      duplicatesSkipped: duplicates,
    );
  }
}

class DatasetStats {
  final int newImagesSinceLastTrain;
  final Map<String, ClassImageCount> classes;
  final List<String> knownClasses;
  final int totalRaw;
  final int totalProcessed;
  final int totalUnsynced;
  final int totalDuplicatesSkipped;

  DatasetStats({
    required this.newImagesSinceLastTrain,
    required this.classes,
    required this.knownClasses,
    required this.totalRaw,
    required this.totalProcessed,
    this.totalUnsynced = 0,
    this.totalDuplicatesSkipped = 0,
  });

  factory DatasetStats.fromJson(Map<String, dynamic> json) {
    final classesMap = <String, ClassImageCount>{};
    if (json['classes'] is Map) {
      (json['classes'] as Map).forEach((k, v) {
        if (v is Map) {
          classesMap[k.toString()] = ClassImageCount.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    final totalR = json['total_raw'] as int? ?? 0;
    final totalP = json['total_processed'] as int? ?? 0;
    final totalU = json['total_unsynced'] as int? ?? (totalR > totalP ? totalR - totalP : 0);
    final totalD = json['total_duplicates_skipped'] as int? ??
        classesMap.values.fold<int>(0, (sum, item) => sum + item.duplicatesSkipped);

    return DatasetStats(
      newImagesSinceLastTrain: json['new_images_since_last_train'] as int? ?? 0,
      classes: classesMap,
      knownClasses: (json['known_classes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      totalRaw: totalR,
      totalProcessed: totalP,
      totalUnsynced: totalU,
      totalDuplicatesSkipped: totalD,
    );
  }
}
