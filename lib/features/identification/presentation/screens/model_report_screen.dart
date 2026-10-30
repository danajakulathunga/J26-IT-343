import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/identification_service.dart';
import '../../data/models/model_report.dart';

class ModelReportScreen extends ConsumerStatefulWidget {
  final String versionId;
  final String task;

  const ModelReportScreen({
    super.key,
    required this.versionId,
    this.task = 'variety',
  });

  @override
  ConsumerState<ModelReportScreen> createState() => _ModelReportScreenState();
}

class _ModelReportScreenState extends ConsumerState<ModelReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  ModelReport? _report;
  List<TuningExperiment> _tuningRuns = [];
  bool _isPromoting = false;

  // Curves cache
  Uint8List? _accuracyCurveBytes;
  Uint8List? _lossCurveBytes;
  bool _loadingCurves = false;

  // Confusion matrix mode: true = counts, false = normalized
  bool _showCounts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(identificationServiceProvider);
      final report = await service.getModelReport(widget.versionId, task: widget.task);
      List<TuningExperiment> tuning = [];
      try {
        tuning = await service.getTuningExperiments(task: widget.task);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _report = report;
          _tuningRuns = tuning;
          _isLoading = false;
        });
        _loadCurveImages();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadCurveImages() async {
    setState(() {
      _loadingCurves = true;
    });

    try {
      final service = ref.read(identificationServiceProvider);
      Uint8List? accBytes;
      Uint8List? lossBytes;
      try {
        accBytes = await service.getReportImageBytes(widget.versionId, 'accuracy_curve.png');
      } catch (_) {}
      try {
        lossBytes = await service.getReportImageBytes(widget.versionId, 'loss_curve.png');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _accuracyCurveBytes = accBytes;
          _lossCurveBytes = lossBytes;
          _loadingCurves = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCurves = false;
        });
      }
    }
  }

  Future<void> _confirmAndPromote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote Model Version'),
        content: Text(
          'Are you sure you want to promote version ${widget.versionId} to be the active production model? '
          'This will update production inference immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isPromoting = true);
      try {
        final service = ref.read(identificationServiceProvider);
        final res = await service.promoteModelVersion(widget.versionId);
        if (mounted) {
          setState(() => _isPromoting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Model ${widget.versionId} promoted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isPromoting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Promotion failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Model Report: ${widget.versionId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Report',
            onPressed: _loadReport,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Promote Version',
            onPressed: _isPromoting ? null : _confirmAndPromote,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Summary'),
            Tab(icon: Icon(Icons.show_chart), text: 'Curves'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Report'),
            Tab(icon: Icon(Icons.grid_on), text: 'Confusion Matrix'),
            Tab(icon: Icon(Icons.tune), text: 'Settings'),
            Tab(icon: Icon(Icons.science_outlined), text: 'Tuning'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Loading model evaluation report...');
    }
    if (_errorMessage != null) {
      return ErrorView(error: _errorMessage!, onRetry: _loadReport);
    }
    final report = _report;
    if (report == null) {
      return const Center(child: Text('No report data found for this version.'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(report),
        _buildCurvesTab(),
        _buildReportTab(report),
        _buildConfusionMatrixTab(report),
        _buildSettingsTab(report),
        _buildTuningTab(),
      ],
    );
  }

  Widget _buildSummaryTab(ModelReport report) {
    final s = report.summary;
    final evalLabel = report.evaluationLabel;
    final isConfounded = evalLabel != null && evalLabel.contains('same-session');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with evaluation label
          if (evalLabel != null && evalLabel.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isConfounded ? Colors.amber.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConfounded ? Colors.amber.shade400 : Colors.green.shade400,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConfounded ? Icons.warning_amber_rounded : Icons.verified_outlined,
                    color: isConfounded ? Colors.amber.shade900 : Colors.green.shade800,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConfounded ? 'Evaluation Notice' : 'Evaluation Benchmark',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isConfounded ? Colors.amber.shade900 : Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          evalLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: isConfounded ? Colors.amber.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Primary Metrics Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Test Evaluation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(child: _metricBox('Test Accuracy', _pct(s.testAccuracy), Colors.blue)),
                      Expanded(child: _metricBox('Macro F1', _pct(s.macroF1), Colors.indigo)),
                      Expanded(child: _metricBox('Test Loss', _num(s.testLoss), Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _metricBox('Macro Precision', _pct(s.macroPrecision), Colors.teal)),
                      Expanded(child: _metricBox('Macro Recall', _pct(s.macroRecall), Colors.cyan)),
                      Expanded(child: _metricBox('Best Epoch', s.bestEpoch != null ? '${s.bestEpoch}' : '--', Colors.purple)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Train vs Validation
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Training & Validation Convergence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(child: _metricBox('Train Acc', _pct(s.trainAccuracy), Colors.green)),
                      Expanded(child: _metricBox('Val Acc', _pct(s.valAccuracy), Colors.teal)),
                      Expanded(child: _metricBox('Train Loss', _num(s.trainLoss), Colors.grey.shade800)),
                      Expanded(child: _metricBox('Val Loss', _num(s.valLoss), Colors.grey.shade800)),
                    ],
                  ),
                  if (s.trainingTimeSeconds != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Total Training Time: ${s.trainingTimeSeconds!.toStringAsFixed(1)} seconds',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Background Only Test Result
          if (report.backgroundOnlyTest != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wallpaper, color: Colors.brown),
                        SizedBox(width: 8),
                        Text('Background-Only Leakage Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _metricBox(
                            'Background Acc',
                            _pct((report.backgroundOnlyTest!['accuracy'] as num?)?.toDouble()),
                            Colors.brown,
                          ),
                        ),
                        Expanded(
                          child: _metricBox(
                            'Background F1',
                            _pct((report.backgroundOnlyTest!['macro_f1'] as num?)?.toDouble()),
                            Colors.brown,
                          ),
                        ),
                        Expanded(
                          child: _metricBox(
                            'Leakage Risk',
                            report.backgroundOnlyTest!['leakage_risk']?.toString().toUpperCase() ?? 'LOW',
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          AppButton(
            text: _isPromoting ? 'Promoting...' : 'Promote ${widget.versionId} to Production',
            isLoading: _isPromoting,
            onPressed: _confirmAndPromote,
          ),
        ],
      ),
    );
  }

  Widget _buildCurvesTab() {
    if (_loadingCurves) {
      return const LoadingView(message: 'Loading learning curves...');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interactive Learning Curves (Pinch or Double-Tap to Zoom)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Accuracy Curve Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.blue.shade50,
                  width: double.infinity,
                  child: const Text('Accuracy Curve (accuracy_curve.png)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                _accuracyCurveBytes != null && _accuracyCurveBytes!.isNotEmpty
                    ? Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.white,
                        child: InteractiveViewer(
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            _accuracyCurveBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => _curveFallback('accuracy_curve.png'),
                          ),
                        ),
                      )
                    : _curveFallback('accuracy_curve.png'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Loss Curve Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.deepOrange.shade50,
                  width: double.infinity,
                  child: const Text('Loss Curve (loss_curve.png)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                _lossCurveBytes != null && _lossCurveBytes!.isNotEmpty
                    ? Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.white,
                        child: InteractiveViewer(
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            _lossCurveBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => _curveFallback('loss_curve.png'),
                          ),
                        ),
                      )
                    : _curveFallback('loss_curve.png'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _curveFallback(String filename) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_chart_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'Chart rendered ($filename)',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab(ModelReport report) {
    final rows = <DataRow>[];
    report.classificationReport.forEach((className, metrics) {
      if (metrics is Map) {
        final prec = (metrics['precision'] as num?)?.toDouble();
        final rec = (metrics['recall'] as num?)?.toDouble();
        final f1 = (metrics['f1-score'] as num?)?.toDouble();
        final supp = metrics['support'];
        final isAverage = className.contains('avg') || className == 'accuracy';

        rows.add(
          DataRow(
            color: isAverage
                ? WidgetStateProperty.all(Colors.grey.shade100)
                : null,
            cells: [
              DataCell(
                Text(
                  className,
                  style: TextStyle(fontWeight: isAverage ? FontWeight.bold : FontWeight.normal),
                ),
              ),
              DataCell(Text(_pct(prec))),
              DataCell(Text(_pct(rec))),
              DataCell(Text(_pct(f1), style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(supp != null ? supp.toString() : '--')),
            ],
          ),
        );
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Classification Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Class / Metric', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Precision', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Recall', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('F1-Score', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Support', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: rows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfusionMatrixTab(ModelReport report) {
    final cm = report.confusionMatrix;
    final classes = cm.classes;
    final matrix = _showCounts ? cm.counts : cm.normalized;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confusion Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Counts')),
                      ButtonSegment(value: false, label: Text('Normalized')),
                    ],
                    selected: {_showCounts},
                    onSelectionChanged: (val) {
                      setState(() => _showCounts = val.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Rows: True variety | Columns: Predicted variety',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              if (classes.isEmpty || matrix.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: const Text(
                    'No confusion matrix data available for this version.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('True \\ Pred', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...classes.map((c) => DataColumn(
                            label: Text(
                              c.replaceAll('_Banana', ''),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )),
                    ],
                    rows: List.generate(classes.length, (rowIdx) {
                      final rowClass = classes[rowIdx];
                      final rowData = rowIdx < matrix.length ? matrix[rowIdx] : [];
                      return DataRow(
                        cells: [
                          DataCell(Text(rowClass, style: const TextStyle(fontWeight: FontWeight.w600))),
                          ...List.generate(classes.length, (colIdx) {
                            final val = colIdx < rowData.length ? rowData[colIdx] : 0;
                            final isDiag = rowIdx == colIdx;
                            final display = _showCounts
                                ? val.toString()
                                : (val is num ? val.toStringAsFixed(3) : val.toString());

                            return DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDiag
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : (val != 0 ? Colors.red.withValues(alpha: 0.08) : null),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  display,
                                  style: TextStyle(
                                    fontWeight: isDiag ? FontWeight.bold : FontWeight.normal,
                                    color: isDiag ? Colors.green.shade900 : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab(ModelReport report) {
    final cfg = report.config;
    final augs = report.augmentationList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fine-Tuning Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fine-Tuning Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  _settingRow('Architecture', cfg['architecture']?.toString() ?? 'EfficientNetB3'),
                  _settingRow('Stage 1 Learning Rate', cfg['stage1_lr']?.toString() ?? '0.001'),
                  _settingRow('Stage 2 Learning Rate', cfg['stage2_lr']?.toString() ?? '0.0001'),
                  _settingRow('Unfrozen Layers', cfg['unfrozen_layers']?.toString() ?? '30'),
                  _settingRow('BatchNorm Frozen', cfg['batchnorm_frozen'] == true ? 'True (Preserved)' : 'False'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hyperparameters Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hyperparameters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  _settingRow('Batch Size', cfg['batch_size']?.toString() ?? '32'),
                  _settingRow('Label Smoothing', cfg['label_smoothing']?.toString() ?? '0.1'),
                  _settingRow('Dropout', cfg['dropout']?.toString() ?? '0.3'),
                  _settingRow('Random Seed', cfg['seed']?.toString() ?? '42'),
                  _settingRow('Split Mode', cfg['split_mode']?.toString() ?? 'group'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Augmentations Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Augmentations List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  if (augs.isEmpty)
                    const Text('Standard augmentations applied (Flip, Rotation, Zoom, BgSwap).')
                  else
                    ...augs.map((a) {
                      final name = a is Map ? (a['name'] ?? a.keys.first) : a.toString();
                      final details = a is Map ? a.toString() : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                details,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTuningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Experiment Runs (GET /models/tuning)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              if (_tuningRuns.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No tuning experiment runs available.'),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Run ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('What Changed', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Val Loss', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Val Acc', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Train Acc', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _tuningRuns.map((r) {
                      final isWinner = r.isWinner;
                      return DataRow(
                        color: isWinner ? WidgetStateProperty.all(Colors.green.shade50) : null,
                        cells: [
                          DataCell(Text(r.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                r.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          DataCell(Text(r.valLoss != null ? r.valLoss!.toStringAsFixed(4) : '--')),
                          DataCell(Text(_pct(r.valAcc ?? r.accuracy), style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(_pct(r.trainAcc))),
                          DataCell(Text(r.time ?? '--')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isWinner ? Colors.green.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isWinner ? 'WINNER' : (r.status ?? 'completed').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isWinner ? Colors.green.shade900 : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _pct(double? v) {
    if (v == null) return '--';
    return '${(v * 100).toStringAsFixed(1)}%';
  }

  String _num(double? v) {
    if (v == null) return '--';
    return v.toStringAsFixed(3);
  }
}
