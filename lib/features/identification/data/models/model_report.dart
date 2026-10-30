class ReportSummary {
  final double? trainAccuracy;
  final double? trainLoss;
  final double? valAccuracy;
  final double? valLoss;
  final double? testAccuracy;
  final double? testLoss;
  final double? macroPrecision;
  final double? macroRecall;
  final double? macroF1;
  final int? bestEpoch;
  final double? trainingTimeSeconds;

  ReportSummary({
    this.trainAccuracy,
    this.trainLoss,
    this.valAccuracy,
    this.valLoss,
    this.testAccuracy,
    this.testLoss,
    this.macroPrecision,
    this.macroRecall,
    this.macroF1,
    this.bestEpoch,
    this.trainingTimeSeconds,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      trainAccuracy: (json['train_accuracy'] as num?)?.toDouble(),
      trainLoss: (json['train_loss'] as num?)?.toDouble(),
      valAccuracy: (json['val_accuracy'] as num?)?.toDouble(),
      valLoss: (json['val_loss'] as num?)?.toDouble(),
      testAccuracy: (json['test_accuracy'] as num?)?.toDouble(),
      testLoss: (json['test_loss'] as num?)?.toDouble(),
      macroPrecision: (json['macro_precision'] as num?)?.toDouble(),
      macroRecall: (json['macro_recall'] as num?)?.toDouble(),
      macroF1: (json['macro_f1'] as num?)?.toDouble(),
      bestEpoch: (json['best_epoch'] as num?)?.toInt(),
      trainingTimeSeconds: (json['training_time_seconds'] as num?)?.toDouble(),
    );
  }
}

class ReportConfusionMatrix {
  final List<String> classes;
  final List<List<dynamic>> counts;
  final List<List<dynamic>> normalized;

  ReportConfusionMatrix({
    required this.classes,
    required this.counts,
    required this.normalized,
  });

  factory ReportConfusionMatrix.fromJson(Map<String, dynamic> json, {List<String>? fallbackClasses}) {
    final rawCls = json['class_names'] ?? json['classes'];
    List<String> cls = (rawCls as List?)?.map((e) => e.toString()).toList() ?? [];
    if (cls.isEmpty && fallbackClasses != null && fallbackClasses.isNotEmpty) {
      cls = fallbackClasses;
    }
    final cnt = (json['counts'] as List?)
            ?.map((row) => (row as List).map((e) => e).toList())
            .toList() ??
        [];
    final nrm = (json['normalized'] as List?)
            ?.map((row) => (row as List).map((e) => e).toList())
            .toList() ??
        [];
    return ReportConfusionMatrix(
      classes: cls,
      counts: cnt,
      normalized: nrm,
    );
  }
}

class ModelReport {
  final String versionId;
  final String task;
  final ReportSummary summary;
  final Map<String, dynamic> classificationReport;
  final ReportConfusionMatrix confusionMatrix;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic> config;
  final List<dynamic> augmentationList;
  final String? evaluationLabel;
  final Map<String, dynamic>? backgroundOnlyTest;

  ModelReport({
    required this.versionId,
    required this.task,
    required this.summary,
    required this.classificationReport,
    required this.confusionMatrix,
    required this.history,
    required this.config,
    required this.augmentationList,
    this.evaluationLabel,
    this.backgroundOnlyTest,
  });

  factory ModelReport.fromJson(Map<String, dynamic> json) {
    final classRep = json['classification_report'] is Map
        ? Map<String, dynamic>.from(json['classification_report'])
        : <String, dynamic>{};
    final fallbackClasses = classRep.keys
        .where((k) => k != 'macro avg' && k != 'weighted avg' && k != 'accuracy')
        .toList();

    return ModelReport(
      versionId: json['version_id'] as String? ?? '',
      task: json['task'] as String? ?? 'variety',
      summary: ReportSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary']) : {}),
      classificationReport: classRep,
      confusionMatrix: ReportConfusionMatrix.fromJson(
        json['confusion_matrix'] is Map ? Map<String, dynamic>.from(json['confusion_matrix']) : {},
        fallbackClasses: fallbackClasses,
      ),
      history: (json['history'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      config: json['config'] is Map ? Map<String, dynamic>.from(json['config']) : {},
      augmentationList: json['augmentation_list'] as List? ?? [],
      evaluationLabel: json['evaluation_label'] as String?,
      backgroundOnlyTest: json['background_only_test'] is Map ? Map<String, dynamic>.from(json['background_only_test']) : null,
    );
  }
}

class TuningExperiment {
  final String id;
  final String name;
  final double? valLoss;
  final double? valAcc;
  final double? trainAcc;
  final double? trainValGap;
  final String? time;
  final bool isWinner;
  final double? macroF1;
  final double? accuracy;
  final int? batchSize;
  final double? learningRate;
  final String? description;
  final String? status;

  TuningExperiment({
    required this.id,
    required this.name,
    this.valLoss,
    this.valAcc,
    this.trainAcc,
    this.trainValGap,
    this.time,
    this.isWinner = false,
    this.macroF1,
    this.accuracy,
    this.batchSize,
    this.learningRate,
    this.description,
    this.status,
  });

  factory TuningExperiment.fromJson(Map<String, dynamic> json) {
    final id = json['run_id'] as String? ?? json['id'] as String? ?? '';
    final name = json['what_changed'] as String? ?? json['name'] as String? ?? id;
    final valLoss = (json['best_val_loss'] as num?)?.toDouble() ?? (json['val_loss'] as num?)?.toDouble();
    final valAcc = (json['best_val_acc'] as num?)?.toDouble() ??
        (json['val_acc'] as num?)?.toDouble() ??
        (json['val_accuracy'] as num?)?.toDouble() ??
        (json['accuracy'] as num?)?.toDouble();
    final trainAcc = (json['final_train_acc'] as num?)?.toDouble() ?? (json['train_acc'] as num?)?.toDouble();
    final trainValGap = (json['train_val_gap'] as num?)?.toDouble();
    final timeStr = json['time'] as String?;
    final isWinner = json['is_winner'] == true ||
        (json['winner'] == true) ||
        id == 'T1' ||
        name.toLowerCase().contains('winner') ||
        name.toLowerCase().contains('baseline');

    return TuningExperiment(
      id: id,
      name: name,
      valLoss: valLoss,
      valAcc: valAcc,
      trainAcc: trainAcc,
      trainValGap: trainValGap,
      time: timeStr,
      isWinner: isWinner,
      macroF1: (json['macro_f1'] as num?)?.toDouble() ?? valAcc,
      accuracy: valAcc,
      batchSize: (json['batch_size'] as num?)?.toInt(),
      learningRate: (json['learning_rate'] as num?)?.toDouble(),
      description: json['description'] as String? ?? name,
      status: json['status'] as String? ?? (isWinner ? 'winner' : 'completed'),
    );
  }
}
