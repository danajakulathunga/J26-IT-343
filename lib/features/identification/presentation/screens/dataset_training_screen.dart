import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../data/identification_service.dart';
import '../../data/models/dataset_stats.dart';
import '../../data/models/training_status.dart';
import '../../data/models/sync_status.dart';
import 'model_report_screen.dart';

class DatasetTrainingScreen extends ConsumerStatefulWidget {
  const DatasetTrainingScreen({super.key});

  @override
  ConsumerState<DatasetTrainingScreen> createState() => _DatasetTrainingScreenState();
}

class _DatasetTrainingScreenState extends ConsumerState<DatasetTrainingScreen> {
  DatasetStats? _stats;
  TrainingStatus? _trainingStatus;
  SyncStatus? _syncStatus;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;

  String _selectedArch = 'efficientnetb3';
  final TextEditingController _epochsStage1Controller = TextEditingController(text: '10');
  final TextEditingController _epochsStage2Controller = TextEditingController(text: '5');
  final TextEditingController _bgSwapProbController = TextEditingController(text: '0.6');
  String? _justTrainedVersionId;

  Timer? _statusPollTimer;
  Timer? _syncPollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _syncPollTimer?.cancel();
    _epochsStage1Controller.dispose();
    _epochsStage2Controller.dispose();
    _bgSwapProbController.dispose();
    super.dispose();
  }

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController(
      text: ApiIdentificationService.effectiveAdminApiKey,
    );
    final newKey = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Admin API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the backend ADMIN_API_KEY required for dataset management and training.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'e.g. testkey',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newKey != null && mounted) {
      await ApiIdentificationService.setDynamicAdminApiKey(newKey);
      _loadData();
    }
  }

  void _startPollingIfNeeded() {
    if (_trainingStatus?.status == 'running') {
      if (_statusPollTimer == null || !_statusPollTimer!.isActive) {
        _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _fetchTrainingStatus();
        });
      }
    } else {
      _statusPollTimer?.cancel();
      _statusPollTimer = null;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiIdentificationService.loadPersistedApiKey();

      // If no admin API key is provided, stop loading and show the set API key prompt
      if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final service = ref.read(identificationServiceProvider);
      final stats = await service.getDatasetStats();
      final status = await service.getTrainingStatus();
      SyncStatus? syncStatus;
      try {
        syncStatus = await service.getSyncStatus();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stats = stats;
          _trainingStatus = status;
          _syncStatus = syncStatus;
          _isSyncing = syncStatus?.status == 'running';
          _isLoading = false;
        });
        _startPollingIfNeeded();
        _startSyncPollingIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  void _startSyncPollingIfNeeded() {
    if (_syncStatus?.status == 'running' || _isSyncing) {
      if (_syncPollTimer == null || !_syncPollTimer!.isActive) {
        _syncPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _fetchSyncStatus();
        });
      }
    } else {
      _syncPollTimer?.cancel();
      _syncPollTimer = null;
    }
  }

  Future<void> _fetchSyncStatus() async {
    try {
      final service = ref.read(identificationServiceProvider);
      final status = await service.getSyncStatus();
      if (mounted) {
        final wasRunning = _isSyncing || _syncStatus?.status == 'running';
        final isNowRunning = status.status == 'running';

        setState(() {
          _syncStatus = status;
          _isSyncing = isNowRunning;
        });
        _startSyncPollingIfNeeded();

        // If sync just completed, reload stats
        if (wasRunning && !isNowRunning) {
          final stats = await service.getDatasetStats();
          if (mounted) {
            setState(() => _stats = stats);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _triggerRawSync() async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (!mounted || ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final service = ref.read(identificationServiceProvider);
      await service.triggerSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Raw folder scan started!')),
      );
      _fetchSyncStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start sync: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fetchTrainingStatus() async {
    try {
      final service = ref.read(identificationServiceProvider);
      final status = await service.getTrainingStatus();
      if (mounted) {
        final wasRunning = _trainingStatus?.status == 'running';
        final isNowRunning = status.status == 'running';
        if (wasRunning && !isNowRunning) {
          _justTrainedVersionId = status.newVersionId ?? status.versionId;
          final updatedStats = await service.getDatasetStats();
          if (mounted) setState(() => _stats = updatedStats);
        }
        setState(() => _trainingStatus = status);
        _startPollingIfNeeded();
      }
    } catch (_) {}
  }



  String _estimateTrainingTime(String arch, int epochs) {
    int secPerEpoch = 11;
    if (arch == 'mobilenetv2') {
      secPerEpoch = 2;
    } else if (arch == 'efficientnetb0') {
      secPerEpoch = 5;
    } else {
      secPerEpoch = 11;
    }
    final totalSec = (epochs * secPerEpoch * 1.5).round();
    if (totalSec < 60) {
      return '$totalSec seconds';
    }
    final mins = (totalSec / 60).toStringAsFixed(1);
    return '$mins minutes (~$totalSec s)';
  }

  Future<void> _showTrainConfirmDialog() async {
    final e1 = int.tryParse(_epochsStage1Controller.text.trim()) ?? 10;
    final e2 = int.tryParse(_epochsStage2Controller.text.trim()) ?? 5;
    final prob = double.tryParse(_bgSwapProbController.text.trim()) ?? 0.6;
    final totalEpochs = e1 + e2;
    final estimatedTime = _estimateTrainingTime(_selectedArch, totalEpochs);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.blue),
            SizedBox(width: 8),
            Text('Confirm Training Run'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start training a new candidate model version with:'),
            const SizedBox(height: 10),
            Text('• Architecture: ${_selectedArch.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('• Schedule: $e1 Stage 1 + $e2 Stage 2 ($totalEpochs total epochs)'),
            Text('• Background-swap probability: $prob'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estimated time: ~$estimatedTime',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Train new version'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _startTraining(e1, e2, prob);
    }
  }

  Future<void> _startTraining(int e1, int e2, double bgSwapProb) async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (!mounted || ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    try {
      final service = ref.read(identificationServiceProvider);
      final res = await service.triggerTraining(
        epochs1: e1,
        epochs2: e2,
        arch: _selectedArch,
        bgSwapProb: bgSwapProb,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Training candidate started!')),
      );
      _fetchTrainingStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger training: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openModelReport(String versionId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelReportScreen(versionId: versionId, task: 'variety'),
      ),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _promoteModel(String versionId) async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (!mounted || ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote Model Version'),
        content: Text(
          'Promote version $versionId to active production model? '
          'This will replace the currently active model immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final service = ref.read(identificationServiceProvider);
        final res = await service.promoteModelVersion(versionId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Model $versionId promoted!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotion failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rollback(String version) async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (!mounted || ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback Model Version'),
        content: Text('Rollback active model to version $version?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final service = ref.read(identificationServiceProvider);
        await service.rollbackVersion(version);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rolled back to $version successfully!')),
        );
        _fetchTrainingStatus();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rollback failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingView(message: 'Loading dataset & training status...')),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dataset & Training'),
          actions: [
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Configure Admin API Key',
              onPressed: _showApiKeyDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: _loadData,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorView(error: _errorMessage!, onRetry: _loadData),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.key),
                  label: const Text('Configure Admin API Key'),
                  onPressed: _showApiKeyDialog,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stats = _stats;
    final training = _trainingStatus;
    final hasApiKey = ApiIdentificationService.effectiveAdminApiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dataset & Model Training'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Configure Admin API Key',
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Key Warning if not set
            if (!hasApiKey)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin API Key is not set. Tap "Set Key" to configure authentication.',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _showApiKeyDialog,
                      child: const Text('Set Key'),
                    ),
                  ],
                ),
              ),

            // Raw Folder Sync Panel
            _buildRawSyncCard(stats),
            const SizedBox(height: 20),

            // Training Status Panel
            _buildTrainingPanel(training),
            const SizedBox(height: 20),

            // Version History & Rollback
            if (training != null && training.history.isNotEmpty)
              _buildHistoryCard(training),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingPanel(TrainingStatus? training) {
    final status = training?.status ?? 'idle';
    final isRunning = status == 'running';
    final activeVer = training?.activeVersion ?? 'initial';
    final metrics = training?.activeMetrics ?? {};
    final testAcc = metrics['test_accuracy'];
    final macroF1 = metrics['macro_f1'];

    // Find candidate item to show post-training completion banner
    TrainingHistoryItem? candidateItem;
    if (training != null && training.history.isNotEmpty) {
      if (_justTrainedVersionId != null) {
        for (final item in training.history) {
          if (item.version == _justTrainedVersionId) {
            candidateItem = item;
            break;
          }
        }
      }
      if (candidateItem == null) {
        for (final item in training.history) {
          if (item.status == 'candidate' && item.version != activeVer) {
            candidateItem = item;
            break;
          }
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Model Training & Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? Colors.orange.shade100
                        : (status == 'failed' ? Colors.red.shade100 : Colors.green.shade100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isRunning
                          ? Colors.orange.shade900
                          : (status == 'failed' ? Colors.red.shade900 : Colors.green.shade900),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: _metricTile('Active Version', activeVer)),
                if (testAcc != null)
                  Expanded(child: _metricTile('Active Test Acc', '${(testAcc * 100).toStringAsFixed(1)}%')),
                if (macroF1 != null)
                  Expanded(child: _metricTile('Active Macro F1', '${(macroF1 * 100).toStringAsFixed(1)}%')),
              ],
            ),
            if (metrics['is_legacy_confounded'] == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Text(
                  'same-session test: not a generalisation estimate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],

            // LIVE PROGRESS (phase, epoch x/y, new version id such as v0009)
            if (isRunning) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phase: ${training?.phase ?? "Training"}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        Text(
                          'Epoch ${training?.epoch ?? 0}/${training?.total ?? 15}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Candidate Version: ${training?.newVersionId ?? training?.versionId ?? training?.currentRun?['version'] ?? "running"}',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (training?.total != null && training!.total! > 0)
                          ? ((training.epoch ?? 0) / training.total!).clamp(0.0, 1.0)
                          : null,
                    ),
                  ],
                ),
              ),
            ],

            // WHEN DONE: Show "{v0009} trained" with test accuracy and macro-F1 and two buttons: "View more" and "Promote"
            if (!isRunning && candidateItem != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade400, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade800, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '${candidateItem.version} trained',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            candidateItem.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Test Accuracy: ${candidateItem.accuracy != null ? (candidateItem.accuracy! * 100).toStringAsFixed(1) : "--"}%',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade900),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Macro F1: ${candidateItem.macroF1 != null ? (candidateItem.macroF1! * 100).toStringAsFixed(1) : "--"}%',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('View more'),
                            onPressed: () => _openModelReport(candidateItem!.version),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.rocket_launch),
                            label: const Text('Promote'),
                            onPressed: () => _promoteModel(candidateItem!.version),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Train New Candidate Version', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Dropdown: Select model architecture (EfficientNetB3 default, MobileNetV2, EfficientNetB0)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedArch,
              decoration: const InputDecoration(
                labelText: 'Select model architecture',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'efficientnetb3',
                  child: Text(
                    'EfficientNetB3 (Default - 300px, Deep)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'mobilenetv2',
                  child: Text(
                    'MobileNetV2 (300px - Fast, Lightweight)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'efficientnetb0',
                  child: Text(
                    'EfficientNetB0 (300px - Balanced)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: isRunning
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedArch = val);
                    },
            ),
            const SizedBox(height: 12),

            // Fields for epochs stage 1 and 2 (default 10 and 5)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _epochsStage1Controller,
                    keyboardType: TextInputType.number,
                    enabled: !isRunning,
                    decoration: const InputDecoration(
                      labelText: 'Stage 1 Epochs',
                      hintText: '10',
                      border: OutlineInputBorder(),
                      helperText: 'Frozen base',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _epochsStage2Controller,
                    keyboardType: TextInputType.number,
                    enabled: !isRunning,
                    decoration: const InputDecoration(
                      labelText: 'Stage 2 Epochs',
                      hintText: '5',
                      border: OutlineInputBorder(),
                      helperText: 'Fine-tuning',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // BG-swap probability field (0.6 default)
            TextFormField(
              controller: _bgSwapProbController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !isRunning,
              decoration: const InputDecoration(
                labelText: 'Background-swap probability',
                hintText: '0.6',
                border: OutlineInputBorder(),
                helperText: 'Default 0.6 (mixes white, grey, and Cavendish border colours)',
              ),
            ),
            const SizedBox(height: 16),

            // Button "Train new version"
            AppButton(
              text: isRunning ? 'Training in Progress...' : 'Train new version',
              isLoading: isRunning,
              onPressed: isRunning ? null : () => _showTrainConfirmDialog(),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildRawSyncCard(DatasetStats? stats) {
    final sync = _syncStatus;
    final isSyncing = _isSyncing || sync?.status == 'running';
    final progress = sync?.progress;
    final summary = sync?.lastSummary;
    final unsynced = stats?.totalUnsynced ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sync, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text(
                      'Dataset & Photos Sync',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (unsynced > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unsynced unsynced',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scans hand-copied images in data/images/raw/, applies preprocessing, and registers them into the dataset.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),

            // Per-class Table (raw, processed, unsynced, duplicates skipped)
            if (stats != null && stats.classes.isNotEmpty) ...[
              const Text(
                'Per-Class Dataset Counts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Raw', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Processed', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Unsynced', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Duplicates Skipped', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    ...stats.classes.entries.map((entry) {
                      final u = entry.value.unsyncedCount;
                      return DataRow(
                        cells: [
                          DataCell(Text(entry.key)),
                          DataCell(Text(entry.value.rawCount.toString())),
                          DataCell(Text(entry.value.processedCount.toString())),
                          DataCell(
                            Text(
                              u.toString(),
                              style: TextStyle(
                                color: u > 0 ? Colors.orange.shade800 : null,
                                fontWeight: u > 0 ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                          DataCell(Text(entry.value.duplicatesSkipped.toString())),
                        ],
                      );
                    }),
                    // Total summary row
                    DataRow(
                      color: WidgetStateProperty.all(Colors.grey.shade100),
                      cells: [
                        const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(stats.totalRaw.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(stats.totalProcessed.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Text(
                            stats.totalUnsynced.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: stats.totalUnsynced > 0 ? Colors.orange.shade800 : null,
                            ),
                          ),
                        ),
                        DataCell(Text(stats.totalDuplicatesSkipped.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Progress bar if syncing
            if (isSyncing) ...[
              if (progress != null && progress.total > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Syncing: ${progress.done}/${progress.total} images (${(progress.percent * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    if (progress.etaSeconds > 0)
                      Text('ETA: ${progress.etaSeconds}s', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress.percent),
              ] else ...[
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Syncing raw photos in background...', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Last Sync Summary Card
            if (summary != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildSummaryBadge('New Processed', summary.totalNew.toString(), Colors.green),
                  _buildSummaryBadge('Already Synced', summary.totalAlreadySynced.toString(), Colors.blue),
                  _buildSummaryBadge('Duplicates Skipped', summary.totalDuplicate.toString(), Colors.orange),
                  _buildSummaryBadge('Rejected', summary.totalRejected.toString(), Colors.red),
                  if (summary.totalIgnored > 0)
                    _buildSummaryBadge('Ignored', summary.totalIgnored.toString(), Colors.grey),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Elapsed time: ${summary.totalTimeSeconds}s (${summary.imagesPerSecond.toStringAsFixed(1)} img/s)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
            ],

            // Button "Sync new photos"
            AppButton(
              text: isSyncing ? 'Syncing...' : 'Sync new photos',
              isLoading: isSyncing,
              onPressed: isSyncing ? null : () => _triggerRawSync(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade900),
      ),
    );
  }

  Widget _buildHistoryCard(TrainingStatus training) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Model Version History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: training.history.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, idx) {
                final item = training.history[idx];
                final isCurrent = item.version == training.activeVersion;

                Color badgeBg = Colors.grey.shade200;
                Color badgeFg = Colors.grey.shade800;
                if (item.status == 'promoted') {
                  badgeBg = Colors.green.shade100;
                  badgeFg = Colors.green.shade800;
                } else if (item.status == 'candidate') {
                  badgeBg = Colors.blue.shade100;
                  badgeFg = Colors.blue.shade800;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item.version, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Test Acc: ${item.accuracy != null ? (item.accuracy! * 100).toStringAsFixed(1) : "--"}% | '
                        'Macro F1: ${item.macroF1 != null ? (item.macroF1! * 100).toStringAsFixed(1) : "--"}% | '
                        '${item.reason ?? "manual"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.analytics_outlined, size: 14),
                            label: const Text('View more', style: TextStyle(fontSize: 12)),
                            onPressed: () => _openModelReport(item.version),
                          ),
                          if (!isCurrent)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.status == 'promoted' ? Colors.orange.shade700 : Colors.green.shade700,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              icon: Icon(item.status == 'promoted' ? Icons.replay : Icons.rocket_launch, size: 14),
                              label: Text(
                                item.status == 'promoted' ? 'Rollback' : 'Promote',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                if (item.status == 'promoted') {
                                  _rollback(item.version);
                                } else {
                                  _promoteModel(item.version);
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
