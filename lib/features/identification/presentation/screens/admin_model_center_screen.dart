import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../data/identification_service.dart';
import '../../data/models/variety_result.dart';
import '../../data/models/model_version_info.dart';

class AdminModelCenterScreen extends ConsumerStatefulWidget {
  const AdminModelCenterScreen({super.key});

  @override
  ConsumerState<AdminModelCenterScreen> createState() => _AdminModelCenterScreenState();
}

class _AdminModelCenterScreenState extends ConsumerState<AdminModelCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Registry state
  List<ModelVersionInfo> _models = [];
  bool _isLoadingModels = false;
  bool _includeExperiments = true;

  // Compare state
  final Set<String> _compareVersionIds = {'active'};
  AsyncValue<Map<String, VarietyResult>?> _compareState = const AsyncData(null);
  String? _compareImagePath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    await ApiIdentificationService.loadPersistedApiKey();
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    setState(() => _isLoadingModels = true);
    try {
      final service = ref.read(identificationServiceProvider);
      final models = await service.getModelVersions(includeExperiments: _includeExperiments);
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
          if (_compareVersionIds.length < 2 && models.length > 1) {
            for (final m in models) {
              if (m.available && m.id != 'active') {
                _compareVersionIds.add(m.id);
                break;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingModels = false);
      }
    }
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
            Icon(Icons.key, color: Color(0xFF266E4E)),
            SizedBox(width: 8),
            Text('Admin API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A non-active model version requires the backend ADMIN_API_KEY.',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF266E4E), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newKey != null && mounted) {
      await ApiIdentificationService.setDynamicAdminApiKey(newKey);
      _fetchModels();
    }
  }

  Future<String?> _pickFile() async {
    String? filePath;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
      );
      if (files.isNotEmpty) {
        filePath = files.first.path;
      }
    } catch (_) {
      try {
        final img = await _picker.pickImage(source: ImageSource.gallery);
        filePath = img?.path;
      } catch (_) {}
    }
    return filePath;
  }

  Future<void> _pickAndRunCompare() async {
    final filePath = await _pickFile();
    if (filePath != null && filePath.isNotEmpty) {
      setState(() => _compareImagePath = filePath);
      _runCompare();
    }
  }

  Future<void> _runCompare() async {
    if (_compareImagePath == null) return;

    if (_compareVersionIds.length < 2 || _compareVersionIds.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select between 2 and 4 versions to compare.')),
      );
      return;
    }

    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    setState(() => _compareState = const AsyncLoading());
    try {
      final service = ref.read(identificationServiceProvider);
      final results = await service.compareModels(
        _compareImagePath!,
        _compareVersionIds.toList(),
      );
      if (mounted) {
        setState(() => _compareState = AsyncData(results));
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _compareState = AsyncError(e, st));
      }
    }
  }

  Future<void> _togglePin(ModelVersionInfo model) async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    final newPin = !model.pinned;
    try {
      final service = ref.read(identificationServiceProvider);
      await service.pinModelVersion(model.id, newPin);
      if (mounted) {
        setState(() {
          _models = _models.map((m) => m.id == model.id ? m.copyWith(pinned: newPin) : m).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPin ? 'Pinned ${model.id}' : 'Unpinned ${model.id}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pin: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _promoteModel(ModelVersionInfo model) async {
    if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) {
      await _showApiKeyDialog();
      if (ApiIdentificationService.effectiveAdminApiKey.isEmpty) return;
    }

    try {
      final service = ref.read(identificationServiceProvider);
      await service.promoteModelVersion(model.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promoted ${model.id} to Active Model!'),
            backgroundColor: const Color(0xFF266E4E),
          ),
        );
        _fetchModels();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to promote model: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      appBar: AppBar(
        title: const Text('Admin Model Center'),
        backgroundColor: const Color(0xFF1E513A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Dataset Training',
            onPressed: () => context.push('/identification/training'),
          ),
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Admin API Key',
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Models',
            onPressed: _fetchModels,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.memory), text: 'Model Registry'),
            Tab(icon: Icon(Icons.compare_arrows), text: 'Compare Models'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistryTab(),
          _buildCompareTab(),
        ],
      ),
    );
  }

  Widget _buildRegistryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Models (${_models.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Row(
                children: [
                  const Text('Show Experiments', style: TextStyle(fontSize: 13)),
                  Switch(
                    value: _includeExperiments,
                    activeThumbColor: const Color(0xFF266E4E),
                    onChanged: (val) {
                      setState(() => _includeExperiments = val);
                      _fetchModels();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingModels
              ? const LoadingView(message: 'Loading model registry...')
              : _models.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.memory, size: 54, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No model versions found.'),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchModels,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        final m = _models[index];
                        final isAvail = m.available;

                        Color statusColor = Colors.grey;
                        if (m.status == 'promoted' || m.isActive) {
                          statusColor = const Color(0xFF266E4E);
                        } else if (m.status == 'rejected') {
                          statusColor = Colors.red;
                        } else if (m.status == 'experiment') {
                          statusColor = Colors.purple;
                        } else if (m.status == 'initial') {
                          statusColor = Colors.blue;
                        } else if (m.status == 'placeholder' || m.status == 'synthetic_baseline') {
                          statusColor = Colors.orange;
                        }

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      m.isActive ? Icons.stars : Icons.memory,
                                      color: m.isActive ? const Color(0xFF266E4E) : statusColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        m.id == 'active' ? 'Active Production Model' : m.id,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    if (m.isActive && m.id != 'active')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF266E4E),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m.status.toUpperCase(),
                                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Architecture: ${m.architecture.toUpperCase()} • Size: ${m.imageSize}'
                                  '${m.testAccuracy != null ? ' • Acc: ${(m.testAccuracy! * 100).toStringAsFixed(1)}%' : ''}'
                                  '${m.macroF1 != null ? ' • F1: ${m.macroF1!.toStringAsFixed(3)}' : ''}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                        color: m.pinned ? Colors.orange : Colors.grey,
                                      ),
                                      tooltip: m.pinned ? 'Unpin model' : 'Pin model',
                                      onPressed: isAvail ? () => _togglePin(m) : null,
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.analytics_outlined, size: 18),
                                      label: const Text('Report'),
                                      onPressed: () {
                                        context.push('/identification/models/${m.id}/report?task=variety');
                                      },
                                    ),
                                    if (!m.isActive && m.status != 'rejected')
                                      TextButton.icon(
                                        icon: const Icon(Icons.arrow_upward, size: 18, color: Color(0xFF266E4E)),
                                        label: const Text('Promote', style: TextStyle(color: Color(0xFF266E4E))),
                                        onPressed: isAvail ? () => _promoteModel(m) : null,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCompareTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Multi-Model Evaluator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select 2 to 4 models from the registry and upload a test photo to run side-by-side inference.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _models.map((m) {
                      final isSelected = _compareVersionIds.contains(m.id);
                      return FilterChip(
                        label: Text(m.id == 'active' ? 'Active' : m.id),
                        selected: isSelected,
                        selectedColor: const Color(0xFF266E4E).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF266E4E),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _compareVersionIds.add(m.id);
                            } else {
                              _compareVersionIds.remove(m.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: _compareImagePath == null ? 'Select Image to Compare' : 'Change Image & Run',
                    onPressed: _pickAndRunCompare,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _compareState.when(
            data: (results) {
              if (results == null || results.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Comparison Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 10),
                  ...results.entries.map((entry) {
                    final version = entry.key;
                    final res = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF266E4E),
                          child: Text(
                            version.substring(0, version.length.clamp(0, 3)).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text('${res.variety} (${(res.confidence * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Model: $version • Fruit: ${res.fruitType}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: res.confidence > 0.85 ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            res.confidence > 0.85 ? 'HIGH CONFIDENCE' : 'MODERATE',
                            style: TextStyle(
                              color: res.confidence > 0.85 ? Colors.green.shade800 : Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const LoadingView(message: 'Running side-by-side inference across models...'),
            error: (err, _) => ErrorView(
              error: 'Failed to run comparison: $err',
              onRetry: _runCompare,
            ),
          ),
        ],
      ),
    );
  }
}
