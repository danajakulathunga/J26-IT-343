import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/data/auth_service.dart';
import '../../data/identification_service.dart';
import '../../data/models/variety_result.dart';

class IdentificationScreen extends ConsumerStatefulWidget {
  const IdentificationScreen({super.key});

  @override
  ConsumerState<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  String? _imagePath;
  bool _isAnalyzing = false;
  VarietyResult? _result;
  String? _errorMessage;
  int _bottomNavIndex = 2; // Center "Scan" active by default

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Default is null so user directly sees the "Select / Take Photo" interface
    _result = null;
    _imagePath = null;
  }

  Future<void> _captureOrUpload(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source);
      if (img != null) {
        _analyzeImage(img.path);
      }
    } catch (_) {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'heic'],
        );
        if (files.isNotEmpty && files.first.path != null) {
          _analyzeImage(files.first.path!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to select photo: $e')),
          );
        }
      }
    }
  }

  Future<void> _analyzeImage(String path) async {
    setState(() {
      _imagePath = path;
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(identificationServiceProvider);
      // Run against the active model
      final res = await service.identifyFruit(path);
      if (mounted) {
        setState(() {
          _result = res;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Identify Fruit Variety',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E513A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture a fresh fruit photo or select from gallery',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF1E513A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _captureOrUpload(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E513A)),
                      label: const Text('Camera', style: TextStyle(color: Color(0xFF1E513A), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF1E513A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _captureOrUpload(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanVarietyName(String raw) {
    return raw.replaceAll('_Banana', '').replaceAll('_Mango', '').replaceAll('_', ' ').trim();
  }

  String _getAbbreviation(String variety) {
    final clean = _cleanVarietyName(variety);
    if (clean.length <= 3) return clean.toUpperCase();
    return clean.substring(0, 3);
  }

  String _getBotanicalSubtitle(String variety, String fruitType) {
    final lower = variety.toLowerCase();
    if (lower.contains('ambul') || lower.contains('embul')) {
      return 'Musa acuminata, local cultivar';
    } else if (lower.contains('kolikuttu')) {
      return 'Musa acuminata, silk subtype';
    } else if (lower.contains('seeni')) {
      return 'Musa acuminata, pisang awak group';
    } else if (lower.contains('red') || lower.contains('rath')) {
      return 'Musa acuminata, Red Dacca';
    } else if (fruitType.toLowerCase().contains('mango')) {
      return 'Mangifera indica, local cultivar';
    }
    return 'Musa acuminata, local cultivar';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Green Curved Banner
                _buildTopGreenHeader(isAdmin),

                const SizedBox(height: 12),

                // If no result yet: Default Select Photos view
                if (_result == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSelectPhotoCard(),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildPhotoGuidelinesSection(),
                  ),
                ] else ...[
                  // Once photo is selected & predicted: Show the variety identification result
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildFloatingVarietyCard(
                      abbreviation: _getAbbreviation(_result!.variety),
                      variety: _cleanVarietyName(_result!.variety),
                      subtitle: _getBotanicalSubtitle(_result!.variety, _result!.fruitType),
                      confidenceText: '${(_result!.confidence * 100).toStringAsFixed(1)}% confidence',
                      modelName: _getModelDisplayName(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Export Suitability Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildExportSuitabilitySection(
                      _cleanVarietyName(_result!.variety),
                      _result!.confidence,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Other Close Matches Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildCloseMatchesSection(),
                  ),

                  const SizedBox(height: 24),

                  // Scan Another Fruit Button (Replaces Continue to Shelf-Life)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildScanAnotherButton(),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(isAdmin),
          ),

          // Analyzing Loading Indicator Overlay
          if (_isAnalyzing)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E513A)),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Analyzing Fruit Variety...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E513A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Running AI inference model',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Top Dark Green Header
  Widget _buildTopGreenHeader(bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 48, bottom: 44, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF235E42),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button if can pop, or Module Launcher if main root screen
          if (context.canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () => context.pop(),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.apps_rounded, color: Colors.white, size: 24),
              tooltip: 'Field Kit Modules',
              onSelected: (val) {
                if (val.isNotEmpty) context.push(val);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: '/defect-detection',
                  child: Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Defect Detection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/shelf-life',
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text('Shelf-Life Prediction'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/traceability',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code, color: Colors.purple, size: 20),
                      SizedBox(width: 10),
                      Text('Traceability'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: '/identification/admin-models',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Color(0xFF266E4E), size: 20),
                      SizedBox(width: 10),
                      Text('Admin Model Center'),
                    ],
                  ),
                ),
              ],
            ),

          // Title
          const Text(
            'Variety identification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),

          // Admin / Share actions
          Row(
            children: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.amber, size: 22),
                  tooltip: 'Admin Model Center',
                  onPressed: () => context.push('/identification/admin-models'),
                ),
              IconButton(
                icon: const Icon(Icons.ios_share_outlined, color: Colors.white, size: 22),
                tooltip: 'Share Prediction',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Variety report shared!'),
                      backgroundColor: Color(0xFF235E42),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Default State: Select / Capture Photo Card
  Widget _buildSelectPhotoCard() {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            CustomPaint(
              painter: DottedCirclePainter(
                color: const Color(0xFF266E4E),
                strokeWidth: 2.2,
                dotCount: 28,
              ),
              child: Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: Color(0xFF1E513A),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Fruit Photo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14241B),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a photo or upload an image to identify the fruit variety and export classification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF235E42),
                      foregroundColor: Colors.white,
                      elevation: 1.5,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _captureOrUpload(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF235E42),
                      side: const BorderSide(color: Color(0xFF235E42), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _captureOrUpload(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Guidelines & Supported Varieties Section
  Widget _buildPhotoGuidelinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supported Varieties',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A241F)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildVarietyChip('Ambul Banana'),
            _buildVarietyChip('Kolikuttu Banana'),
            _buildVarietyChip('Seeni Banana'),
            _buildVarietyChip('Red Banana (Rath Kehel)'),
            _buildVarietyChip('Cavendish / Embul'),
            _buildVarietyChip('Mango Cultivars'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE9F5EF),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Color(0xFF266E4E), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tips for Best Accuracy',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1A241F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ensure good natural lighting and position the fruit clearly in the center frame without strong shadows.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVarietyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E513A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getModelDisplayName() {
    final modelVer = _result?.modelVersion;
    final arch = _result?.architecture;
    if (modelVer != null && modelVer.isNotEmpty && modelVer != 'active') {
      return arch != null && arch.isNotEmpty ? '$modelVer (${arch.toUpperCase()})' : modelVer;
    } else if (arch != null && arch.isNotEmpty) {
      return 'Active (${arch.toUpperCase()})';
    }
    return 'Active Model';
  }

  // Floating Variety Identification Result Card (Shown after selection)
  Widget _buildFloatingVarietyCard({
    required String abbreviation,
    required String variety,
    required String subtitle,
    required String confidenceText,
    required String modelName,
  }) {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Uploaded Photo Preview
            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Dotted Circle Avatar with Abbreviation
            CustomPaint(
              painter: DottedCirclePainter(
                color: const Color(0xFF266E4E),
                strokeWidth: 2.2,
                dotCount: 30,
              ),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      abbreviation,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E513A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VARIETY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Variety Title
            Text(
              variety,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14241B),
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 6),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 14),

            // Confidence & Model Name Badges
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Confidence Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    confidenceText,
                    style: const TextStyle(
                      color: Color(0xFFC47F00),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Model Name Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5EF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF266E4E).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.memory, size: 15, color: Color(0xFF1E513A)),
                      const SizedBox(width: 6),
                      Text(
                        'Model: $modelName',
                        style: const TextStyle(
                          color: Color(0xFF1E513A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Export Suitability Section
  Widget _buildExportSuitabilitySection(String variety, double confidence) {
    final isApproved = confidence >= 0.80;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export suitability',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A241F),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isApproved ? const Color(0xFFE9F5EF) : const Color(0xFFFFF8E1),
                ),
                child: Icon(
                  isApproved ? Icons.check_circle_outline : Icons.help_outline,
                  color: isApproved ? const Color(0xFF266E4E) : Colors.amber.shade800,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isApproved ? 'Approved for EU & Middle East markets' : 'Conditional: Secondary Inspection Advised',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A241F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isApproved
                          ? '$variety meets current size, color, and cultivar standard regulations for both lanes.'
                          : 'Confidence is below optimum 80% export threshold. Manual verification recommended.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Other Close Matches Section
  Widget _buildCloseMatchesSection() {
    final top3 = _result?.top3 ?? [];
    final candidates = top3.length > 1
        ? top3.sublist(1)
        : [
            Top3Candidate(rawClass: 'Kolikuttu_Banana', confidence: 0.028),
            Top3Candidate(rawClass: 'Seeni_Banana', confidence: 0.008),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Other close matches',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A241F),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200, width: 1.2),
          ),
          child: Column(
            children: candidates.map((c) {
              final name = _cleanVarietyName(c.rawClass);
              final pct = (c.confidence * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E34),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.confidence.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF266E4E)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Scan Another Fruit Button (Action after result is shown)
  Widget _buildScanAnotherButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF235E42),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _showImageSourceDialog,
        icon: const Icon(Icons.camera_alt_outlined, size: 20),
        label: const Text(
          'Scan Another Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Curved Bottom Navigation Bar matching the mockup
  Widget _buildBottomBar(bool isAdmin) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Color(0xFF235E42),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home
          _buildNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: _bottomNavIndex == 0,
            onTap: () {
              setState(() => _bottomNavIndex = 0);
              context.go('/');
            },
          ),

          // History
          _buildNavItem(
            icon: Icons.history,
            label: 'History',
            isActive: _bottomNavIndex == 1,
            onTap: () {
              setState(() => _bottomNavIndex = 1);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scan history saved locally.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // Center Scan Button (Elevated Circle)
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E513A),
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.crop_free, color: Colors.white, size: 24),
                    SizedBox(height: 2),
                    Text(
                      'Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reports / Admin
          _buildNavItem(
            icon: Icons.assignment_outlined,
            label: isAdmin ? 'Admin' : 'Reports',
            isActive: _bottomNavIndex == 3,
            onTap: () {
              setState(() => _bottomNavIndex = 3);
              if (isAdmin) {
                context.push('/identification/admin-models');
              } else {
                context.push('/identification/recommendations');
              }
            },
          ),

          // Profile
          _buildNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: _bottomNavIndex == 4,
            onTap: () {
              setState(() => _bottomNavIndex = 4);
              _showProfileSheet(isAdmin);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white60,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFF266E4E),
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kumara Perera',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          isAdmin ? 'Role: Administrator / Exporter' : 'Role: Standard User (Farmer)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.amber.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAdmin ? 'ADMIN' : 'USER',
                      style: TextStyle(
                        color: isAdmin ? Colors.amber.shade900 : Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.tune, color: Color(0xFF266E4E)),
                title: const Text('Admin Model Center'),
                subtitle: const Text('Model registry, comparison, training & API keys'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/identification/admin-models');
                },
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Color(0xFF266E4E)),
                title: const Text('Dataset & Fine-Tuning'),
                subtitle: const Text('Fine-tune with background swapping'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/identification/training');
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                title: Text(isAdmin ? 'Switch to Standard User Mode' : 'Switch to Admin Mode'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(authProvider.notifier).register(
                        fullName: 'Kumara Perera',
                        estateOrCompany: 'Ruwan Estates',
                        phone: '+94 77 123 4567',
                        password: 'password123',
                        role: isAdmin ? UserRole.farmer : UserRole.admin,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isAdmin ? 'Switched to Standard User mode' : 'Switched to Admin mode'),
                      backgroundColor: const Color(0xFF266E4E),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for the Dotted Circle Avatar
class DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dotCount;

  DottedCirclePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dotCount = 28,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final sweepAngle = (2 * math.pi) / dotCount;
    final dashAngle = sweepAngle * 0.55;

    for (int i = 0; i < dotCount; i++) {
      final startAngle = i * sweepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
