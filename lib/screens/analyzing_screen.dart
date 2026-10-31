import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/scan_provider.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';

class AnalyzingScreen extends ConsumerStatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Run analysis after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAnalysis();
    });
  }

  Future<void> _runAnalysis() async {
    final lang = ref.read(localeProvider).languageCode;
    final success = await ref.read(scanProvider.notifier).analyzeImage(lang);

    if (!mounted) return;

    if (success) {
      final scanResult = ref.read(scanProvider).scanResult;
      if (scanResult != null) {
        context.pushReplacement('/result/${scanResult.scanId}');
      } else {
        context.pushReplacement('/result');
      }
      return;
    }

    // Check if the failure was a "not banana" rejection
    final scanState = ref.read(scanProvider);
    if (scanState.isBananaError) {
      _showNotBananaDialog(lang);
    }
  }

  void _showNotBananaDialog(String lang) {
    final title = lang == 'si'
        ? 'කෙසෙල් ඡායාරූපයක් අවශ්‍යයි'
        : (lang == 'ta'
            ? 'வாழைப்பழ படம் தேவை'
            : 'Banana Image Required');
    final message = lang == 'si'
        ? 'මෙම app එකෙහි කෙසෙල් පළතුරු පමණක් scan කළ හැකිය.\n\nකරුණාකර කෙසෙල් ගෙඩියක ඡායාරූපයක් ගෙන නැවත උත්සාහ කරන්න.'
        : (lang == 'ta'
            ? 'இந்த app இல் வாழைப்பழ படங்கள் மட்டுமே ஸ்கேன் செய்யலாம்.\n\nதயவுசெய்து வாழைப்பழத்தின் தெளிவான புகைப்படம் எடுத்து மீண்டும் முயற்சிக்கவும்.'
            : 'This app only supports banana fruit images.\n\nPlease capture or select a clear photo of a banana and try again.');
    final btnLabel = lang == 'si'
        ? 'නැවත උත්සාහ කරන්න'
        : (lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Try Again');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ref.read(scanProvider.notifier).reset();
          }
        },
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155), width: 1.2),
          ),
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning icon badge styled to app theme (no emojis)
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF1F5F9),
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Close',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(scanProvider.notifier).reset();
                    if (mounted) context.pop();
                  },
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            // Single primary "Try Again" button styled to app theme
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(scanProvider.notifier).reset();
                  if (mounted) context.pop(); // go back to scan screen to pick again
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 19),
                label: Text(btnLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancel() {
    ref.read(scanProvider.notifier).cancelAnalysis();
    if (mounted) context.pop();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanState = ref.watch(scanProvider);
    final lang = ref.watch(localeProvider).languageCode;

    // Failure State: Never leave an infinite spinner
    if (scanState.isFailed) {
      // Show banana-specific dialog instead of generic error screen
      if (scanState.isBananaError) {
        // Dialog is shown by _runAnalysis(); show a neutral waiting scaffold
        return const Scaffold(
          body: SizedBox.shrink(),
        );
      }
      return _buildErrorView(context, theme, scanState, lang);
    }

    // Progress Labels
    final isUploading = scanState.status == ScanStatus.uploading;
    final progressPct = (scanState.uploadProgress * 100).toInt();

    String title;
    String subtitle;
    String cancelLabel = 'Cancel';

    if (lang == 'si') {
      title = isUploading ? 'ඡායාරූපය උඩුගත කරමින් පවතී...' : 'විශ්ලේෂණය කරමින් පවතී...';
      subtitle = isUploading
          ? 'කෙසෙල් ඡායාරූපය ආරක්ෂිතව සේවාදායකයට යොමු කරමින් පවතී ($progressPct%)'
          : 'රෝග හඳුනාගැනීම, බරපතලකම සහ Grad-CAM පැහැදිලි කිරීම ක්‍රියාත්මක වේ.';
      cancelLabel = 'අවලංගු කරන්න';
    } else if (lang == 'ta') {
      title = isUploading ? 'புகைப்படம் பதிவேற்றப்படுகிறது...' : 'பகுப்பாய்வு செய்கிறது...';
      subtitle = isUploading
          ? 'புகைப்படம் சேவையகத்திற்கு அனுப்பப்படுகிறது ($progressPct%)'
          : 'நோயறிதல், தீவிரம் மற்றும் Grad-CAM விளக்கம் இயங்குகிறது.';
      cancelLabel = 'ரத்து செய்';
    } else {
      title = isUploading ? 'Uploading Banana Photo...' : 'Analyzing Banana...';
      subtitle = isUploading
          ? 'Securely transferring photo to diagnostic engine ($progressPct%)'
          : 'Running condition detection, severity estimation, and Grad-CAM explainability.';
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.primaryGreen.withOpacity(0.12),
                        ),
                      ),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.primaryGreen,
                        ),
                        child: const Icon(
                          Icons.biotech_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // File metadata badge
                if (scanState.fileName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined, size: 16, color: AppConstants.primaryGreen),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            scanState.fileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (scanState.fileSizeBytes > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${_formatFileSize(scanState.fileSizeBytes)})',
                            style: TextStyle(fontSize: 11, color: theme.hintColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Upload Progress Bar
                if (isUploading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: scanState.uploadProgress > 0 ? scanState.uploadProgress : null,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$progressPct%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentYellow),
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(cancelLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, ThemeData theme, ScanState state, String lang) {
    final title = lang == 'si'
        ? 'විශ්ලේෂණය අසාර්ථක විය'
        : (lang == 'ta' ? 'பகுப்பாய்வு தோல்வியடைந்தது' : 'Analysis Failed');

    final message = state.getLocalizedError(lang);

    final retryLabel = lang == 'si'
        ? 'නැවත උත්සාහ කරන්න'
        : (lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry Analysis');

    final backLabel = lang == 'si'
        ? 'ආපසු යන්න'
        : (lang == 'ta' ? 'பின்செல்க' : 'Back to Scan');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Technical details visible in debug mode or if server reported detailed error
                if (state.technicalDetails != null && (kDebugMode || state.technicalDetails!.contains('Backend Error'))) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Technical Detail (Debug):',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          state.technicalDetails!,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Buttons: Retry and Back
                ElevatedButton.icon(
                  onPressed: _runAnalysis,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryLabel),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(backLabel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
