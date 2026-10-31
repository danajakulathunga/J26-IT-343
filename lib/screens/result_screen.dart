import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/providers/scan_provider.dart';
import 'package:bananaguard_ai/services/report_service.dart';
import 'package:bananaguard_ai/widgets/bilingual_text.dart';
import 'package:bananaguard_ai/widgets/demo_banner.dart';
import 'package:bananaguard_ai/widgets/severity_gauge.dart';
import 'package:bananaguard_ai/widgets/zoomable_image.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';
import 'package:bananaguard_ai/providers/history_provider.dart';
import 'package:bananaguard_ai/widgets/server_config_dialog.dart';
import 'package:bananaguard_ai/data/knowledge_base_data.dart';
import 'package:bananaguard_ai/models/condition_info.dart';
import 'package:bananaguard_ai/services/scan_service.dart';
import 'package:bananaguard_ai/widgets/creative_progress_bar.dart';
import 'package:bananaguard_ai/widgets/animated_toast.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final ScanResultModel? scanResult;
  final String? scanId;

  const ResultScreen({super.key, this.scanResult, this.scanId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  int _imageToggle = 0; // 0 = Original, 1 = Highlighted (Grad-CAM)
  bool _isDownloadingPdf = false;
  double _downloadProgress = 0.0;
  bool _showTopPredictions = false;
  ScanResultModel? _loadedScan;
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.scanResult != null) {
      _loadedScan = widget.scanResult;
    } else if (ref.read(scanProvider).scanResult != null) {
      _loadedScan = ref.read(scanProvider).scanResult;
    } else if (widget.scanId != null && widget.scanId!.isNotEmpty) {
      _fetchScan(widget.scanId!);
    }
    // Auto-refresh scan history in the background after the screen entrance animation completes
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        ref.read(historyProvider.notifier).loadHistory();
      }
    });
  }

  Future<void> _fetchScan(String id) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final res = await scanService.getScanById(id);
      if (mounted) {
        setState(() {
          _loadedScan = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  ScanResultModel? get scan {
    return _loadedScan ?? widget.scanResult ?? ref.read(scanProvider).scanResult;
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'disease':
        return AppConstants.severitySevere;
      case 'defect':
        return AppConstants.severityModerate;
      case 'healthy':
      default:
        return AppConstants.primaryGreen;
    }
  }

  Color _getSeverityColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'severe':
        return AppConstants.severitySevere;
      case 'moderate':
        return AppConstants.severityModerate;
      case 'mild':
      default:
        return AppConstants.severityMild;
    }
  }

  Future<void> _downloadReport() async {
    final currentScan = scan;
    if (currentScan == null) return;

    setState(() {
      _isDownloadingPdf = true;
      _downloadProgress = 0.0;
    });

    try {
      final filePath = await reportService.downloadScanReport(
        scanId: currentScan.scanId,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showAnimatedToast(
        context,
        duration: const Duration(seconds: 5),
        bottomOffset: 84.0,
        actionLabel: 'Open',
        actionColor: const Color(0xFFD97706),
        onAction: () => reportService.openReport(filePath),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PDF Report downloaded successfully!',
                style: TextStyle(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().replaceFirst('Exception: ', '');
        final isServerIssue = errorText.contains('Cloudflare') ||
            errorText.contains('530') ||
            errorText.contains('Server URL') ||
            errorText.contains('Cannot reach backend');

        final isDark = Theme.of(context).brightness == Brightness.dark;
        showAnimatedToast(
          context,
          duration: Duration(seconds: isServerIssue ? 10 : 5),
          bottomOffset: 84.0,
          actionLabel: isServerIssue ? 'Server URL' : null,
          actionColor: const Color(0xFFD97706),
          onAction: isServerIssue ? () => showServerConfigDialog(context) : null,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorText,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentScan = scan;
    final lang = ref.watch(localeProvider).languageCode;
    final titleText = lang == 'si'
        ? 'පරීක්ෂණ ප්‍රතිඵලය'
        : (lang == 'ta' ? 'கண்டறிதல் முடிவு' : 'Diagnostic Result');
    final backTooltip = lang == 'si'
        ? 'මුල් පිටුවට'
        : (lang == 'ta' ? 'முகப்புக்குச் செல்க' : 'Back to Home');

    void navigateToHome() {
      ref.read(scanProvider.notifier).reset();
      context.go('/home');
    }

    if (_isLoading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) navigateToHome();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: backTooltip,
              onPressed: navigateToHome,
            ),
            title: Text(titleText),
          ),
          body: const Center(
            child: CircularProgressIndicator(color: AppConstants.accentYellow),
          ),
        ),
      );
    }

    if (currentScan == null) {
      final noResultText = _loadError ?? (lang == 'si'
          ? 'ප්‍රතිඵල නොමැත'
          : (lang == 'ta' ? 'முடிவுகள் எதுவும் இல்லை' : 'No scan result available'));
      final goHomeText = lang == 'si'
          ? 'මුල් පිටුවට'
          : (lang == 'ta' ? 'முகப்புக்குச் செல்க' : 'Go Home');
      final retryText = lang == 'si'
          ? 'නැවත උත්සාහ කරන්න'
          : (lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry');

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) navigateToHome();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: backTooltip,
              onPressed: navigateToHome,
            ),
            title: Text(titleText),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(noResultText, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (widget.scanId != null) ...[
                    ElevatedButton.icon(
                      onPressed: () => _fetchScan(widget.scanId!),
                      icon: const Icon(Icons.refresh),
                      label: Text(retryText),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton(
                    onPressed: navigateToHome,
                    child: Text(goHomeText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final typeColor = _getTypeColor(currentScan.condition.type);
    final shareTooltip = lang == 'si'
        ? 'වාර්තාව බෙදාගන්න'
        : (lang == 'ta' ? 'அறிக்கையைப் பகிரவும்' : 'Share report');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) navigateToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: backTooltip,
            onPressed: navigateToHome,
          ),
          title: Text(titleText),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: shareTooltip,
              onPressed: _downloadReport,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // 1. Demo Mode Banner if mode == "demo"
                    if (currentScan.isDemo) ...[
                      const DemoBanner(),
                      const SizedBox(height: 12),
                    ],

                    // Segmented Toggle: Original | Highlighted (Grad-CAM)
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: [
                          const ButtonSegment(
                            value: 0,
                            label: Text('Original'),
                            icon: Icon(Icons.image_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text(
                              'Highlighted (Grad-CAM)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(fontSize: 12),
                            ),
                            icon: Icon(Icons.center_focus_strong_rounded, size: 18),
                          ),
                        ],
                        selected: {_imageToggle},
                        onSelectionChanged: (val) {
                          setState(() => _imageToggle = val.first);
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppConstants.primaryGreen,
                          selectedForegroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Full uncropped zoomable image viewer (pinch-to-zoom)
                    ZoomableImageViewer(
                      imageUrl: _imageToggle == 0
                          ? currentScan.images.originalUrl
                          : currentScan.images.gradcamUrl,
                      highlightBox: currentScan.highlightBox,
                      showBox: _imageToggle == 1,
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _imageToggle == 1
                            ? (lang == 'si'
                                ? 'Grad-CAM තාප සිතියම සහ දෝෂ ස්ථානගත කිරීමේ viewfinder'
                                : (lang == 'ta'
                                    ? 'Grad-CAM வெப்ப வரைபடம் மற்றும் குறைபாடு கண்டறிதல் viewfinder'
                                    : 'Grad-CAM overlay on original image with defect localization viewfinder'))
                            : (lang == 'si'
                                ? 'මුල් ඡායාරූපය (විශාලනය කළ හැක)'
                                : (lang == 'ta'
                                    ? 'அசல் புகைப்படம் (பெரிதாக்கலாம்)'
                                    : 'Full Original Uploaded Image (Pinch to zoom)')),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Low Confidence Warning banner if condition_confidence < 0.50
                    if (currentScan.lowConfidence) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lang == 'si'
                                    ? 'අඩු විශ්වාසයක් – පැහැදිලි ඡායාරූපයක් නැවත ගන්න'
                                    : (lang == 'ta'
                                        ? 'குறைந்த துல்லியம் – தெளிவான புகைப்படத்தை மீண்டும் எடுக்கவும்'
                                        : 'Low confidence – retake a clearer photo'),
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Quality Warnings (if any)
                    if (currentScan.qualityWarnings.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'si'
                                  ? 'ඡායාරූප තත්ත්ව උපදේශනය:'
                                  : (lang == 'ta'
                                      ? 'படத் தர ஆலோசனை:'
                                      : 'Image Quality Advisory:'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 4),
                            ...currentScan.qualityWarnings.map((w) => Text(
                                  '• ${w.getLocalized(lang)}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 2. Detected Condition Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withOpacity(0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentScan.condition.type.toUpperCase(),
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (currentScan.variety != null)
                                Text(
                                  'Variety: ${currentScan.variety!.en} (${currentScan.variety!.getLocalized(lang)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Builder(builder: (context) {
                            final condInfo = ConditionInfoModel.getConditionById(currentScan.condition.id);
                            final displayEn = (currentScan.condition.en.isNotEmpty && !currentScan.condition.en.contains('_'))
                                ? currentScan.condition.en
                                : (condInfo?.nameEn ?? currentScan.condition.en.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '));
                            final displaySi = currentScan.condition.si.trim().isNotEmpty
                                ? currentScan.condition.si
                                : (condInfo?.nameSi ?? '');
                            final displayTa = (currentScan.condition.ta != null && currentScan.condition.ta!.trim().isNotEmpty)
                                ? currentScan.condition.ta!
                                : (condInfo?.getName('ta') ?? currentScan.condition.getLocalized('ta'));
                            final displayDesc = currentScan.condition.getDescription(lang).trim().isNotEmpty
                                ? currentScan.condition.getDescription(lang)
                                : (condInfo?.getDescription(lang) ?? '');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BilingualText(
                                  textEn: displayEn,
                                  textSi: displaySi,
                                  textTa: displayTa,
                                  primaryStyle: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  secondaryStyle: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                                  ),
                                ),
                                if (displayDesc.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    displayDesc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }),
                          const SizedBox(height: 12),

                          // 3. Condition Confidence (Creative Animated Progress bar + %)
                          AnimatedConfidenceSection(
                            confidence: currentScan.conditionConfidence,
                            title: lang == 'si'
                                ? 'හඳුනාගැනීමේ විශ්වාසනීයත්වය:'
                                : (lang == 'ta'
                                    ? 'நிலை துல்லியத்தன்மை:'
                                    : 'Condition Confidence:'),
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4 & 5. Severity Section
                    if (currentScan.isHealthy)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppConstants.primaryGreen.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppConstants.primaryGreen, size: 36),
                            const SizedBox(height: 6),
                            Text(
                              lang == 'si'
                                  ? 'දෝෂ හෝ රෝග හඳුනා ගෙන නොමැත'
                                  : (lang == 'ta'
                                      ? 'குறைபாடோ நோயோ கண்டறியப்படவில்லை'
                                      : 'No defect or disease detected'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppConstants.primaryGreen),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Severity Level + Severity Index — combined card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Severity Level row
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang == 'si'
                                          ? 'බරපතලකම මට්ටම:'
                                          : (lang == 'ta' ? 'தீவிர நிலை:' : 'Severity Level:'),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getSeverityColor(currentScan.severity?.level).withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getSeverityColor(currentScan.severity?.level)),
                                      ),
                                      child: Text(
                                        currentScan.severity?.getLocalized(lang) ??
                                            (lang == 'si' ? 'නැත' : (lang == 'ta' ? 'இல்லை' : 'None')),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _getSeverityColor(currentScan.severity?.level),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Severity Index gauge (embedded in same card)
                            SeverityGauge(
                              severityIndex: currentScan.severityIndex,
                              severityLevel: currentScan.severity?.level,
                              severityConfidence: currentScan.severityConfidence,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // 6. Cause Factors
                    Builder(builder: (context) {
                      final cleanId = currentScan.condition.id.toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');
                      final sevKey = currentScan.severity?.level.toLowerCase().trim() ??
                          (currentScan.condition.type.toLowerCase() == 'healthy' ? 'healthy' : 'mild');

                      final condInfo = ConditionInfoModel.getConditionById(cleanId);

                      List<LocalizedTextModel> displayCauses = currentScan.causeFactors;
                      if (displayCauses.isEmpty) {
                        displayCauses = condInfo?.getCauseFactorsForSeverity(sevKey) ?? [];
                      }
                      if (displayCauses.isEmpty) {
                        final fallbackMap = KnowledgeBaseData.fallbackSeverityLevels[cleanId];
                        displayCauses = fallbackMap?[sevKey]?.causeFactors ??
                            (fallbackMap?['mild']?.causeFactors ?? (fallbackMap?['healthy']?.causeFactors ?? []));
                      }

                      List<LocalizedTextModel> displayRecs = currentScan.recommendations;
                      if (displayRecs.isEmpty) {
                        displayRecs = condInfo?.getRecommendationsForSeverity(sevKey) ?? [];
                      }
                      if (displayRecs.isEmpty) {
                        final fallbackMap = KnowledgeBaseData.fallbackSeverityLevels[cleanId];
                        displayRecs = fallbackMap?[sevKey]?.recommendations ??
                            (fallbackMap?['mild']?.recommendations ?? (fallbackMap?['healthy']?.recommendations ?? []));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'si'
                                ? 'ප්‍රධාන හේතු සාධක'
                                : (lang == 'ta' ? 'முதன்மைக் காரணிகள்' : 'Primary Cause Factors'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...displayCauses.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final factor = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$idx. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppConstants.primaryGreen,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      factor.getLocalized(lang),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),

                          // 7. Recommendations
                          Text(
                            lang == 'si'
                                ? 'නිර්දේශිත ක්‍රියාමාර්ග'
                                : (lang == 'ta' ? 'பரிந்துரைக்கப்பட்ட நடவடிக்கைகள்' : 'Action Recommendations'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...displayRecs.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final rec = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$idx. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppConstants.primaryGreen,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      rec.getLocalized(lang),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // 8. Grad-CAM Explanation Caption
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppConstants.accentYellow, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'si'
                                      ? 'Grad-CAM පැහැදිලි කිරීමේ සටහන'
                                      : (lang == 'ta'
                                          ? 'Grad-CAM விளக்கக் குறிப்பு'
                                          : 'Grad-CAM Explainability Note'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang == 'si'
                                      ? 'රතු සහ කහ ප්‍රදේශ ස්නායුක ජාල අනාවැකියට වඩාත්ම බලපෑම් කළ ස්ථාන විශේෂණය කරයි.'
                                      : (lang == 'ta'
                                          ? 'சிவப்பு மற்றும் மஞ்சள் பகுதிகள் நரம்பியல் வலைப்பின்னல் கணிப்பை அதிகம் பாதித்த பகுதிகளை முன்னிலைப்படுத்துகின்றன.'
                                          : 'Red & yellow areas highlight regions that most strongly influenced the neural network prediction.'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top 3 alternative predictions (Collapsible)
                    if (currentScan.topPredictions.length > 1) ...[
                      InkWell(
                        onTap: () => setState(() => _showTopPredictions = !_showTopPredictions),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang == 'si'
                                    ? 'විකල්ප අනාවැකි (${currentScan.topPredictions.length})'
                                    : (lang == 'ta'
                                        ? 'மாற்று கணிப்புகள் (${currentScan.topPredictions.length})'
                                        : 'Alternative Predictions (${currentScan.topPredictions.length})'),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Icon(
                                _showTopPredictions
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showTopPredictions)
                        ...currentScan.topPredictions.map((pred) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(pred.getLocalized(lang), style: const TextStyle(fontSize: 13)),
                                Text(
                                  '${(pred.confidence * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                    ],

                    // Disclaimer Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        currentScan.disclaimer.getLocalized(lang),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Actions: Download Report & Scan Again
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Scan Again
                  OutlinedButton(
                    onPressed: () {
                      ref.read(scanProvider.notifier).reset();
                      context.pushReplacement('/scan-capture');
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(110, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      lang == 'si'
                          ? 'තවත් පරීක්ෂාවක්'
                          : (lang == 'ta' ? 'மற்றொன்றை ஸ்கேன் செய்' : 'Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sticky Download Report
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDownloadingPdf ? null : _downloadReport,
                      icon: _isDownloadingPdf
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: _downloadProgress > 0 ? _downloadProgress : null,
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                        _isDownloadingPdf
                            ? (lang == 'si'
                                ? 'වාර්තාව බාගත වේ...'
                                : (lang == 'ta' ? 'பதிவிறக்குகிறது...' : 'Downloading Report...'))
                            : (lang == 'si'
                                ? 'PDF වාර්තාව බාගත කරන්න'
                                : (lang == 'ta' ? 'PDF பதிவிறக்கவும்' : 'Download PDF Report')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
