import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import 'models/variety_result.dart';
import 'models/country_recommendation.dart';
import 'models/market_alert.dart';
import 'models/dataset_stats.dart';
import 'models/training_status.dart';
import 'models/sync_status.dart';
import 'models/model_version_info.dart';
import 'models/model_report.dart';

const List<String> validRipenessStages = ['Green', 'Turning', 'Ripe', 'Overripe'];

abstract class IdentificationService {
  Future<VarietyResult> identifyFruit(String imagePath, {String? modelVersion});
  Future<List<CountryRecommendation>> getExportRecommendations(String variety);
  Future<List<MarketAlert>> getMarketAlerts();

  Future<DatasetStats> getDatasetStats();
  Future<Map<String, dynamic>> uploadDatasetImages(String varietyClass, List<String> filePaths);
  Future<TrainingStatus> getTrainingStatus();
  Future<Map<String, dynamic>> triggerTraining({
    int? epochs1,
    int? epochs2,
    String? arch,
    String? task,
    double? bgSwapProb,
  });
  Future<Map<String, dynamic>> rollbackVersion(String version);

  Future<Map<String, dynamic>> triggerSync({String? varietyClass});
  Future<SyncStatus> getSyncStatus();

  Future<List<ModelVersionInfo>> getModelVersions({bool includeExperiments = false});
  Future<bool> pinModelVersion(String versionId, bool pin);
  Future<Map<String, VarietyResult>> compareModels(String imagePath, List<String> versions);

  Future<ModelReport> getModelReport(String versionId, {String task = 'variety'});
  Future<Uint8List> getReportImageBytes(String versionId, String imageName);
  Future<List<TuningExperiment>> getTuningExperiments({String task = 'variety'});
  Future<Map<String, dynamic>> promoteModelVersion(String versionId);
}

class MockIdentificationService implements IdentificationService {
  final List<ModelVersionInfo> _mockModels = [
    ModelVersionInfo(
      id: 'active',
      isActive: true,
      status: 'promoted',
      architecture: 'mobilenetv2',
      imageSize: '300x300',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.942,
      macroF1: 0.938,
      createdAt: '2026-10-11T12:00:00',
      pinned: true,
      available: true,
    ),
    ModelVersionInfo(
      id: 'v0004',
      isActive: true,
      status: 'promoted',
      architecture: 'mobilenetv2',
      imageSize: '300x300',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.942,
      macroF1: 0.938,
      createdAt: '2026-10-11T12:00:00',
      pinned: true,
      available: true,
    ),
    ModelVersionInfo(
      id: 'v0003',
      isActive: false,
      status: 'legacy',
      architecture: 'mobilenetv2',
      imageSize: '224x224',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.864,
      macroF1: 0.805,
      createdAt: '2026-10-10T14:30:00',
      pinned: false,
      available: true,
    ),
    ModelVersionInfo(
      id: 'v0002',
      isActive: false,
      status: 'rejected',
      architecture: 'mobilenetv2',
      imageSize: '224x224',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.720,
      macroF1: 0.680,
      createdAt: '2026-10-09T10:00:00',
      pinned: false,
      available: false,
    ),
    ModelVersionInfo(
      id: 'initial',
      isActive: false,
      status: 'initial',
      architecture: 'mobilenetv2',
      imageSize: '224x224',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.850,
      macroF1: 0.830,
      createdAt: '2026-10-08T09:00:00',
      pinned: false,
      available: true,
    ),
    ModelVersionInfo(
      id: 'exp_aug_300',
      isActive: false,
      status: 'experiment',
      architecture: 'mobilenetv2',
      imageSize: '300x300',
      classNames: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      testAccuracy: 0.951,
      macroF1: 0.945,
      createdAt: '2026-10-11T16:00:00',
      pinned: false,
      available: true,
    ),
  ];

  @override
  Future<VarietyResult> identifyFruit(String imagePath, {String? modelVersion}) async {
    await Future.delayed(const Duration(seconds: 1));
    final v = modelVersion ?? 'active';
    final is300 = v.contains('300') || v == 'active' || v == 'v0004';
    return VarietyResult(
      fruitType: 'Banana',
      variety: 'Ambul',
      confidence: is300 ? 0.952 : 0.884,
      modelVersion: v,
      imageSize: is300 ? '300x300' : '224x224',
      architecture: 'mobilenetv2',
      top3: [
        Top3Candidate(rawClass: 'Ambul_Banana', confidence: is300 ? 0.952 : 0.884),
        Top3Candidate(rawClass: 'Kolikuttu_Banana', confidence: is300 ? 0.035 : 0.081),
        Top3Candidate(rawClass: 'Seeni_Banana', confidence: is300 ? 0.013 : 0.035),
      ],
      lowConfidence: false,
    );
  }

  @override
  Future<List<ModelVersionInfo>> getModelVersions({bool includeExperiments = false}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (includeExperiments) {
      return List.from(_mockModels);
    }
    return _mockModels.where((m) => m.status != 'experiment').toList();
  }

  @override
  Future<bool> pinModelVersion(String versionId, bool pin) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockModels.indexWhere((m) => m.id == versionId);
    if (index >= 0) {
      _mockModels[index] = _mockModels[index].copyWith(pinned: pin);
      return true;
    }
    return false;
  }

  @override
  Future<Map<String, VarietyResult>> compareModels(String imagePath, List<String> versions) async {
    await Future.delayed(const Duration(seconds: 1));
    final results = <String, VarietyResult>{};
    for (final v in versions) {
      final is300 = v.contains('300') || v == 'active' || v == 'v0004';
      results[v] = VarietyResult(
        fruitType: 'Banana',
        variety: 'Ambul',
        confidence: is300 ? 0.952 : 0.865,
        modelVersion: v,
        imageSize: is300 ? '300x300' : '224x224',
        architecture: 'mobilenetv2',
        top3: [
          Top3Candidate(rawClass: 'Ambul_Banana', confidence: is300 ? 0.952 : 0.865),
          Top3Candidate(rawClass: 'Kolikuttu_Banana', confidence: is300 ? 0.035 : 0.095),
          Top3Candidate(rawClass: 'Seeni_Banana', confidence: is300 ? 0.013 : 0.040),
        ],
        lowConfidence: false,
      );
    }
    return results;
  }

  @override
  Future<List<CountryRecommendation>> getExportRecommendations(String variety) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      CountryRecommendation(
        country: 'UAE',
        exportScore: 88.5,
        demand: 'High',
        avgUnitValueUsdKg: 1.2,
        bestWindow: 'Oct - Dec',
        qualityRequirement: 'Premium',
      ),
    ];
  }

  @override
  Future<List<MarketAlert>> getMarketAlerts() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      MarketAlert(
        type: 'PRICE_DROP',
        message: 'Sudden price drop in UAE markets for Ambul banana.',
        country: 'UAE',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];
  }

  bool _mockSyncRunning = false;
  bool _mockTrainingRunning = false;
  int _mockEpoch = 0;
  int _mockTotalEpochs = 15;
  final String _mockNewVersionId = 'v0009';
  Timer? _mockTrainTimer;

  @override
  Future<DatasetStats> getDatasetStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return DatasetStats(
      newImagesSinceLastTrain: 14,
      classes: {
        'Ambul_Banana': ClassImageCount(rawCount: 45, processedCount: 45, unsyncedCount: 0, duplicatesSkipped: 2),
        'Kolikuttu_Banana': ClassImageCount(rawCount: 52, processedCount: 50, unsyncedCount: 2, duplicatesSkipped: 3),
        'Seeni_Banana': ClassImageCount(rawCount: 38, processedCount: 38, unsyncedCount: 0, duplicatesSkipped: 1),
      },
      knownClasses: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
      totalRaw: 135,
      totalProcessed: 133,
      totalUnsynced: 2,
      totalDuplicatesSkipped: 6,
    );
  }

  @override
  Future<Map<String, dynamic>> uploadDatasetImages(String varietyClass, List<String> filePaths) async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'variety_class': varietyClass,
      'total': filePaths.length,
      'added': filePaths.length,
      'results': filePaths.map((p) => {'file': p.split(r'\').last, 'status': 'added'}).toList(),
    };
  }

  @override
  Future<TrainingStatus> getTrainingStatus() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final history = [
      TrainingHistoryItem(
        version: 'v0009',
        status: 'candidate',
        accuracy: 0.938,
        macroF1: 0.935,
        reason: 'manual',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      ),
      TrainingHistoryItem(
        version: 'v0004',
        status: 'promoted',
        accuracy: 0.942,
        macroF1: 0.938,
        reason: 'manual',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      ),
    ];

    if (_mockTrainingRunning) {
      return TrainingStatus(
        status: 'running',
        phase: _mockEpoch <= 10 ? 'Stage 1 (Frozen Base)' : 'Stage 2 (Fine-tuning)',
        epoch: _mockEpoch,
        total: _mockTotalEpochs,
        versionId: _mockNewVersionId,
        newVersionId: _mockNewVersionId,
        activeVersion: 'v0004',
        activeMetrics: {'test_accuracy': 0.942, 'macro_f1': 0.938},
        history: history,
      );
    }

    return TrainingStatus(
      status: 'idle',
      phase: 'done',
      epoch: _mockTotalEpochs,
      total: _mockTotalEpochs,
      versionId: _mockNewVersionId,
      newVersionId: _mockNewVersionId,
      activeVersion: 'v0004',
      activeMetrics: {'test_accuracy': 0.942, 'macro_f1': 0.938},
      history: history,
    );
  }

  @override
  Future<Map<String, dynamic>> triggerTraining({
    int? epochs1,
    int? epochs2,
    String? arch,
    String? task,
    double? bgSwapProb,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final e1 = epochs1 ?? 10;
    final e2 = epochs2 ?? 5;
    _mockTotalEpochs = e1 + e2;
    _mockEpoch = 1;
    _mockTrainingRunning = true;
    _mockTrainTimer?.cancel();
    _mockTrainTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _mockEpoch++;
      if (_mockEpoch >= _mockTotalEpochs) {
        _mockTrainingRunning = false;
        timer.cancel();
      }
    });
    return {'success': true, 'message': 'Mock training started for ${arch ?? "efficientnetb3"}.'};
  }

  @override
  Future<Map<String, dynamic>> rollbackVersion(String version) async {
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'Mock rolled back to $version.'};
  }

  @override
  Future<Map<String, dynamic>> triggerSync({String? varietyClass}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockSyncRunning = true;
    Timer(const Duration(seconds: 3), () {
      _mockSyncRunning = false;
    });
    return {'status': 'started', 'message': 'Mock sync started.'};
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SyncStatus(
      status: _mockSyncRunning ? 'running' : 'idle',
      progress: _mockSyncRunning
          ? SyncProgress(done: 18, total: 30, speedIps: 6.0, etaSeconds: 2)
          : null,
      lastSummary: SyncSummary(
        status: 'completed',
        totalTimeSeconds: 2.5,
        imagesPerSecond: 12.0,
        totalNew: 8,
        totalAlreadySynced: 22,
        totalDuplicate: 6,
        totalRejected: 0,
        totalIgnored: 0,
        classes: {},
      ),
    );
  }

  @override
  Future<ModelReport> getModelReport(String versionId, {String task = 'variety'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return ModelReport(
      versionId: versionId,
      task: task,
      summary: ReportSummary(
        trainAccuracy: 0.978,
        trainLoss: 0.082,
        valAccuracy: 0.942,
        valLoss: 0.165,
        testAccuracy: 0.938,
        testLoss: 0.178,
        macroPrecision: 0.941,
        macroRecall: 0.936,
        macroF1: 0.938,
        bestEpoch: 12,
        trainingTimeSeconds: 154.2,
      ),
      classificationReport: {
        'Ambul_Banana': {'precision': 0.952, 'recall': 0.935, 'f1-score': 0.943, 'support': 46},
        'Kolikuttu_Banana': {'precision': 0.938, 'recall': 0.950, 'f1-score': 0.944, 'support': 40},
        'Seeni_Banana': {'precision': 0.925, 'recall': 0.918, 'f1-score': 0.921, 'support': 38},
        'macro avg': {'precision': 0.938, 'recall': 0.934, 'f1-score': 0.936, 'support': 124},
      },
      confusionMatrix: ReportConfusionMatrix(
        classes: ['Ambul_Banana', 'Kolikuttu_Banana', 'Seeni_Banana'],
        counts: [
          [43, 2, 1],
          [1, 38, 1],
          [1, 2, 35],
        ],
        normalized: [
          [0.935, 0.043, 0.022],
          [0.025, 0.950, 0.025],
          [0.026, 0.053, 0.921],
        ],
      ),
      history: List.generate(15, (index) {
        final ep = index + 1;
        return {
          'epoch': ep,
          'loss': 0.8 / (ep * 0.7),
          'val_loss': 0.9 / (ep * 0.6),
          'accuracy': 0.6 + (0.38 * (ep / 15)),
          'val_accuracy': 0.58 + (0.36 * (ep / 15)),
          'lr': ep <= 10 ? 0.001 : 0.0001,
          'stage': ep <= 10 ? 1 : 2,
        };
      }),
      config: {
        'architecture': 'efficientnetb3',
        'image_size': [300, 300],
        'batch_size': 32,
        'seed': 42,
        'label_smoothing': 0.1,
        'dropout': 0.3,
        'split_mode': 'group',
        'stage1_lr': 0.001,
        'stage2_lr': 0.0001,
        'unfrozen_layers': 30,
        'batchnorm_frozen': true,
      },
      augmentationList: [
        {'name': 'RandomFlip', 'details': 'horizontal_and_vertical'},
        {'name': 'RandomRotation', 'factor': 0.15},
        {'name': 'RandomZoom', 'height_factor': 0.1, 'width_factor': 0.1},
        {'name': 'BackgroundSwap', 'probability': 0.6},
      ],
      evaluationLabel: 'same-session, not a generalisation estimate',
      backgroundOnlyTest: {
        'accuracy': 0.24,
        'macro_f1': 0.21,
        'leakage_risk': 'low',
      },
    );
  }

  @override
  Future<Uint8List> getReportImageBytes(String versionId, String imageName) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Transparent 1x1 png as valid base
    return base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
  }

  @override
  Future<List<TuningExperiment>> getTuningExperiments({String task = 'variety'}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      TuningExperiment(
        id: 'T1',
        name: 'Baseline: lr-stage2 1e-5, label-smoothing 0.0, bg-swap-prob 0.6',
        valLoss: 0.2153,
        valAcc: 0.9048,
        trainAcc: 0.9578,
        trainValGap: 0.053,
        time: '12.6m',
        isWinner: true,
        macroF1: 0.905,
        accuracy: 0.905,
        status: 'winner',
      ),
      TuningExperiment(
        id: 'T4',
        name: 'Augmentation ablation: bg-swap-prob 0.0',
        valLoss: 0.2707,
        valAcc: 0.8869,
        trainAcc: 0.9554,
        trainValGap: 0.0685,
        time: '12.1m',
        isWinner: false,
        macroF1: 0.887,
        accuracy: 0.887,
        status: 'completed',
      ),
      TuningExperiment(
        id: 'T2',
        name: 'Higher fine-tune LR: lr-stage2 5e-5',
        valLoss: 0.2733,
        valAcc: 0.9107,
        trainAcc: 0.9672,
        trainValGap: 0.0624,
        time: '12.5m',
        isWinner: false,
        macroF1: 0.911,
        accuracy: 0.911,
        status: 'completed',
      ),
      TuningExperiment(
        id: 'T3',
        name: 'Label smoothing regularization: label-smoothing 0.1',
        valLoss: 0.6844,
        valAcc: 0.8929,
        trainAcc: 0.9656,
        trainValGap: 0.0727,
        time: '13.0m',
        isWinner: false,
        macroF1: 0.893,
        accuracy: 0.893,
        status: 'completed',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> promoteModelVersion(String versionId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _mockModels.indexWhere((m) => m.id == versionId);
    if (idx >= 0) {
      _mockModels[idx] = _mockModels[idx].copyWith(isActive: true, status: 'promoted');
    }
    return {'success': true, 'message': 'Mock model version $versionId promoted.'};
  }
}

class ApiIdentificationService implements IdentificationService {
  static const String _prefsKey = 'admin_api_key';
  static String dynamicAdminApiKey = '';
  static const String _compileTimeAdminApiKey = String.fromEnvironment('ADMIN_API_KEY', defaultValue: '');

  static String get effectiveAdminApiKey {
    if (dynamicAdminApiKey.trim().isNotEmpty) {
      return dynamicAdminApiKey.trim();
    }
    final compileKey = _compileTimeAdminApiKey.trim();
    if (compileKey.isNotEmpty && compileKey != 'YOUR_ADMIN_API_KEY_HERE') {
      return compileKey;
    }
    return '';
  }

  static Future<void> loadPersistedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefsKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        dynamicAdminApiKey = savedKey.trim();
      }
    } catch (e) {
      debugPrint('Error reading persisted admin API key: $e');
    }
  }

  static Future<void> setDynamicAdminApiKey(String key) async {
    dynamicAdminApiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (dynamicAdminApiKey.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, dynamicAdminApiKey);
      }
    } catch (e) {
      debugPrint('Error writing persisted admin API key: $e');
    }
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.identificationBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Map<String, String> _getAdminHeaders() {
    final key = effectiveAdminApiKey;
    if (key.isEmpty) {
      throw Exception('ADMIN_API_KEY is not configured. Tap the Key icon to set it, or launch with --dart-define=ADMIN_API_KEY=...');
    }
    return {'X-API-Key': key};
  }

  String _formatError(String operation, Object e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401) {
        return 'Unauthorized: Invalid Admin API Key (401). Tap the key icon to configure it.';
      }
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return '$operation: ${data['detail']}';
      }
    }
    return '$operation: $e';
  }

  @override
  Future<VarietyResult> identifyFruit(String imagePath, {String? modelVersion}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath),
      });

      final isNonActive = modelVersion != null && modelVersion.isNotEmpty && modelVersion != 'active';
      final response = await _dio.post(
        '/predict/',
        data: formData,
        queryParameters: isNonActive ? {'model_version': modelVersion} : null,
        options: isNonActive ? Options(headers: _getAdminHeaders()) : null,
      );
      return VarietyResult.fromJson(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to identify fruit', e));
    }
  }

  @override
  Future<List<ModelVersionInfo>> getModelVersions({bool includeExperiments = false}) async {
    try {
      final response = await _dio.get(
        '/models',
        queryParameters: {'include_experiments': includeExperiments},
        options: Options(headers: _getAdminHeaders()),
      );
      final rawList = response.data is List ? response.data as List : (response.data['models'] as List? ?? []);
      return rawList.map((item) => ModelVersionInfo.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(_formatError('Failed to fetch model versions', e));
    }
  }

  @override
  Future<bool> pinModelVersion(String versionId, bool pin) async {
    try {
      if (pin) {
        await _dio.post(
          '/models/$versionId/pin',
          options: Options(headers: _getAdminHeaders()),
        );
      } else {
        await _dio.delete(
          '/models/$versionId/pin',
          options: Options(headers: _getAdminHeaders()),
        );
      }
      return true;
    } catch (e) {
      throw Exception(_formatError('Failed to update pin state', e));
    }
  }

  @override
  Future<Map<String, VarietyResult>> compareModels(String imagePath, List<String> versions) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath),
        'versions': versions.join(','),
      });

      final response = await _dio.post(
        '/predict/compare',
        data: formData,
        options: Options(headers: _getAdminHeaders()),
      );

      final out = <String, VarietyResult>{};
      final rawResults = response.data['results'] as Map<String, dynamic>? ?? {};
      for (final entry in rawResults.entries) {
        if (entry.value is Map<String, dynamic>) {
          out[entry.key] = VarietyResult.fromJson(entry.value as Map<String, dynamic>);
        }
      }
      return out;
    } catch (e) {
      throw Exception(_formatError('Failed to compare models', e));
    }
  }

  @override
  Future<List<CountryRecommendation>> getExportRecommendations(String variety) async {
    try {
      final response = await _dio.post('/recommend/', queryParameters: {'variety': variety});
      return (response.data as List)
          .map((json) => CountryRecommendation.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recommendations: $e');
    }
  }

  @override
  Future<List<MarketAlert>> getMarketAlerts() async {
    try {
      final response = await _dio.get('/alerts/');
      return (response.data as List)
          .map((json) => MarketAlert.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch alerts: $e');
    }
  }

  @override
  Future<DatasetStats> getDatasetStats() async {
    try {
      final response = await _dio.get(
        '/dataset/stats',
        options: Options(headers: _getAdminHeaders()),
      );
      return DatasetStats.fromJson(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to fetch dataset stats', e));
    }
  }

  @override
  Future<Map<String, dynamic>> uploadDatasetImages(String varietyClass, List<String> filePaths) async {
    try {
      final multipartFiles = <MultipartFile>[];
      for (final p in filePaths) {
        multipartFiles.add(await MultipartFile.fromFile(p));
      }

      final formData = FormData.fromMap({
        'variety_class': varietyClass,
        'files': multipartFiles,
      });

      final response = await _dio.post(
        '/dataset/upload',
        data: formData,
        options: Options(headers: _getAdminHeaders()),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to upload dataset images', e));
    }
  }

  @override
  Future<TrainingStatus> getTrainingStatus() async {
    try {
      final response = await _dio.get(
        '/training/status',
        options: Options(headers: _getAdminHeaders()),
      );
      return TrainingStatus.fromJson(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to fetch training status', e));
    }
  }

  @override
  Future<Map<String, dynamic>> triggerTraining({
    int? epochs1,
    int? epochs2,
    String? arch,
    String? task,
    double? bgSwapProb,
  }) async {
    try {
      final response = await _dio.post(
        '/training/start',
        data: {
          'task': task ?? 'variety',
          'arch': arch ?? 'efficientnetb3',
          'epochs_stage1': epochs1 ?? 10,
          'epochs_stage2': epochs2 ?? 5,
          'bg_swap_prob': bgSwapProb ?? 0.6,
          'reason': 'manual',
        },
        options: Options(headers: _getAdminHeaders()),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to trigger training', e));
    }
  }

  @override
  Future<Map<String, dynamic>> rollbackVersion(String version) async {
    try {
      final response = await _dio.post(
        '/training/rollback',
        data: {'version': version},
        options: Options(headers: _getAdminHeaders()),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to rollback model', e));
    }
  }

  @override
  Future<Map<String, dynamic>> triggerSync({String? varietyClass}) async {
    try {
      final response = await _dio.post(
        '/dataset/sync',
        queryParameters: varietyClass != null ? {'class': varietyClass} : null,
        options: Options(headers: _getAdminHeaders()),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to trigger raw sync', e));
    }
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    try {
      final response = await _dio.get(
        '/dataset/sync/status',
        options: Options(headers: _getAdminHeaders()),
      );
      return SyncStatus.fromJson(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to fetch sync status', e));
    }
  }

  @override
  Future<ModelReport> getModelReport(String versionId, {String task = 'variety'}) async {
    try {
      final response = await _dio.get(
        '/models/$versionId/report',
        queryParameters: {'task': task},
        options: Options(headers: _getAdminHeaders()),
      );
      return ModelReport.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw Exception(_formatError('Failed to fetch model report for $versionId', e));
    }
  }

  @override
  Future<Uint8List> getReportImageBytes(String versionId, String imageName) async {
    try {
      final response = await _dio.get<List<int>>(
        '/models/$versionId/report/image/$imageName',
        options: Options(
          headers: _getAdminHeaders(),
          responseType: ResponseType.bytes,
        ),
      );
      return Uint8List.fromList(response.data ?? []);
    } catch (e) {
      throw Exception(_formatError('Failed to fetch curve image $imageName', e));
    }
  }

  @override
  Future<List<TuningExperiment>> getTuningExperiments({String task = 'variety'}) async {
    try {
      final response = await _dio.get(
        '/models/tuning',
        queryParameters: {'task': task},
        options: Options(headers: _getAdminHeaders()),
      );
      final rawList = (response.data['experiment_runs'] as List?) ?? [];
      return rawList.map((e) => TuningExperiment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw Exception(_formatError('Failed to fetch tuning experiments', e));
    }
  }

  @override
  Future<Map<String, dynamic>> promoteModelVersion(String versionId) async {
    try {
      final response = await _dio.post(
        '/models/$versionId/promote',
        options: Options(headers: _getAdminHeaders()),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception(_formatError('Failed to promote model version $versionId', e));
    }
  }
}

final identificationServiceProvider = Provider<IdentificationService>((ref) {
  if (AppConfig.useMockApi) {
    return MockIdentificationService();
  } else {
    return ApiIdentificationService();
  }
});
