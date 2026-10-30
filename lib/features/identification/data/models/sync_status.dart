class SyncProgress {
  final int done;
  final int total;
  final double speedIps;
  final int etaSeconds;

  SyncProgress({
    required this.done,
    required this.total,
    required this.speedIps,
    required this.etaSeconds,
  });

  factory SyncProgress.fromJson(Map<String, dynamic> json) {
    return SyncProgress(
      done: json['done'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      speedIps: (json['speed_ips'] as num?)?.toDouble() ?? 0.0,
      etaSeconds: json['eta_seconds'] as int? ?? 0,
    );
  }

  double get percent => total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
}

class SyncSummary {
  final String status;
  final double totalTimeSeconds;
  final double imagesPerSecond;
  final int totalNew;
  final int totalAlreadySynced;
  final int totalDuplicate;
  final int totalRejected;
  final int totalIgnored;
  final Map<String, dynamic> classes;

  SyncSummary({
    required this.status,
    required this.totalTimeSeconds,
    required this.imagesPerSecond,
    required this.totalNew,
    required this.totalAlreadySynced,
    required this.totalDuplicate,
    required this.totalRejected,
    required this.totalIgnored,
    required this.classes,
  });

  factory SyncSummary.fromJson(Map<String, dynamic> json) {
    return SyncSummary(
      status: json['status'] as String? ?? 'unknown',
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toDouble() ?? 0.0,
      imagesPerSecond: (json['images_per_second'] as num?)?.toDouble() ?? 0.0,
      totalNew: json['total_new'] as int? ?? 0,
      totalAlreadySynced: json['total_already_synced'] as int? ?? 0,
      totalDuplicate: json['total_duplicate'] as int? ?? 0,
      totalRejected: json['total_rejected'] as int? ?? 0,
      totalIgnored: json['total_ignored'] as int? ?? 0,
      classes: json['classes'] is Map ? Map<String, dynamic>.from(json['classes'] as Map) : {},
    );
  }
}

class SyncStatus {
  final String status; // 'idle' | 'running' | 'failed'
  final SyncProgress? progress;
  final SyncSummary? lastSummary;

  SyncStatus({
    required this.status,
    this.progress,
    this.lastSummary,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      status: json['status'] as String? ?? 'idle',
      progress: json['progress'] is Map ? SyncProgress.fromJson(Map<String, dynamic>.from(json['progress'] as Map)) : null,
      lastSummary: json['last_summary'] is Map ? SyncSummary.fromJson(Map<String, dynamic>.from(json['last_summary'] as Map)) : null,
    );
  }
}
