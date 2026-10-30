class TrainingHistoryItem {
  final String version;
  final String status;
  final double? accuracy;
  final double? macroF1;
  final String? reason;
  final String? timestamp;

  TrainingHistoryItem({
    required this.version,
    required this.status,
    this.accuracy,
    this.macroF1,
    this.reason,
    this.timestamp,
  });

  factory TrainingHistoryItem.fromJson(Map<String, dynamic> json) {
    return TrainingHistoryItem(
      version: json['version'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      macroF1: (json['macro_f1'] as num?)?.toDouble(),
      reason: json['reason'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }
}

class TrainingStatus {
  final String status; // idle | running | done | failed
  final String? phase;
  final int? epoch;
  final int? total;
  final String? versionId;
  final String? newVersionId;
  final Map<String, dynamic>? currentRun;
  final String activeVersion;
  final Map<String, dynamic> activeMetrics;
  final List<TrainingHistoryItem> history;

  TrainingStatus({
    required this.status,
    this.phase,
    this.epoch,
    this.total,
    this.versionId,
    this.newVersionId,
    this.currentRun,
    required this.activeVersion,
    required this.activeMetrics,
    required this.history,
  });

  factory TrainingStatus.fromJson(Map<String, dynamic> json) {
    final historyList = <TrainingHistoryItem>[];
    if (json['history'] is List) {
      for (final item in json['history']) {
        if (item is Map) {
          historyList.add(TrainingHistoryItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final verId = json['version_id'] as String? ?? json['new_version_id'] as String?;

    return TrainingStatus(
      status: json['status'] as String? ?? 'idle',
      phase: json['phase'] as String?,
      epoch: json['epoch'] as int?,
      total: json['total'] as int? ?? json['total_epochs'] as int?,
      versionId: verId,
      newVersionId: json['new_version_id'] as String? ?? verId,
      currentRun: json['current_run'] as Map<String, dynamic>?,
      activeVersion: json['active_version'] as String? ?? 'initial',
      activeMetrics: json['active_metrics'] as Map<String, dynamic>? ?? {},
      history: historyList,
    );
  }
}
