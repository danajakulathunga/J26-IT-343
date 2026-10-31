import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/scan_provider.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';
import 'package:bananaguard_ai/models/condition_info.dart';

class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen> {
  @override
  void initState() {
    super.initState();
    // Reset any previously uploaded/unscanned image on fresh launch & open picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanProvider.notifier).reset();
      _showImageSourceDialog();
    });
  }

  void _showImageSourceDialog() {
    final lang = ref.read(localeProvider).languageCode;
    final dialogTitle = lang == 'si'
        ? 'ඡායාරූප මූලාශ්‍රය තෝරන්න'
        : (lang == 'ta' ? 'புகைப்பட மூலத்தைத் தேர்ந்தெடுக்கவும்' : 'Choose Photo Source');
    final cameraTitle = lang == 'si'
        ? 'කැමරාවෙන් ඡායාරූපයක් ගන්න'
        : (lang == 'ta' ? 'கேமரா மூலம் படம் எடுக்கவும்' : 'Take Photo with Camera');
    final cameraSub = lang == 'si'
        ? 'කැමරාව මඟින් ඡායාරූපයක් ගන්න'
        : (lang == 'ta' ? 'கேமரா மூலம் நேரடியாக படம் எடுக்கவும்' : 'Capture directly using camera');
    final galleryTitle = lang == 'si'
        ? 'ගැලරියෙන් තෝරන්න'
        : (lang == 'ta' ? 'கேலரியில் இருந்து தேர்ந்தெடுக்கவும்' : 'Choose from Gallery');
    final gallerySub = lang == 'si'
        ? 'ගැලරියෙන් ඡායාරූපයක් තෝරන්න'
        : (lang == 'ta' ? 'கேලரியில் இருந்து படத்தை தேர்ந்தெடுக்கவும்' : 'Select an image from device gallery');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dialogTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppConstants.primaryGreen),
                ),
                title: Text(cameraTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(cameraSub),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(scanProvider.notifier).pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.accentYellow.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFFB45309)),
                ),
                title: Text(galleryTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(gallerySub),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(scanProvider.notifier).pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotBananaDialog() {
    final lang = ref.read(localeProvider).languageCode;
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
                  _showImageSourceDialog();
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

  void _proceedToAnalysis() {
    context.push('/analyzing');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanState = ref.watch(scanProvider);
    final lang = ref.watch(localeProvider).languageCode;

    // Reactively trigger Not Banana Dialog if banana check rejected the image
    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.isBananaError && !(prev?.isBananaError ?? false)) {
        _showNotBananaDialog();
      }
    });

    final appBarTitle = lang == 'si'
        ? 'කෙසෙල් පරීක්ෂාව'
        : (lang == 'ta' ? 'வாழைப்பழ ஸ்கேன்' : 'Scan Banana');
    final tooltipText = lang == 'si'
        ? 'වෙනත් ඡායාරූපයක් තෝරන්න'
        : (lang == 'ta' ? 'மற்றொரு புகைப்படத்தைத் தேர்ந்தெடுக்கவும்' : 'Choose another photo');
    final noImageText = lang == 'si'
        ? 'ඡායාරූපයක් තෝරාගෙන නොමැත'
        : (lang == 'ta' ? 'புகைப்படம் எதுவும் தேர்ந்தெடுக்கப்படவில்லை' : 'No image selected');
    final captureBtnText = lang == 'si'
        ? 'ඡායාරූපයක් ගන්න හෝ තෝරන්න'
        : (lang == 'ta' ? 'புகைப்படம் எடுக்கவும் அல்லது தேர்ந்தெடுக்கவும்' : 'Capture or Select Photo');
    final varietyTitle = lang == 'si'
        ? 'කෙසෙල් ප්‍රභේදය (විකල්ප)'
        : (lang == 'ta' ? 'வாழை ரகம் (விருப்பத்தேர்வு)' : 'Banana Variety (Optional)');
    final unspecifiedText = lang == 'si'
        ? 'තහවුරු නැත / සඳහන් කර නැත'
        : (lang == 'ta' ? 'உறுதியாக தெரியவில்லை / குறிப்பிடப்படவில்லை' : 'Not sure / Unspecified');
    final analyzeBtnText = lang == 'si'
        ? 'කෙසෙල් පරීක්ෂා කරන්න'
        : (lang == 'ta' ? 'வாழைப்பழத்தை பகுப்பாய்வு செய்' : 'Analyze Banana');
    final checkingText = lang == 'si'
        ? 'කෙසෙල් පළතුර තහවුරු කරමින් පවතී...'
        : (lang == 'ta' ? 'வாழைப்பழம் சரிபார்க்கப்படுகிறது...' : 'Verifying banana fruit...');
    final verifiedBadgeText = lang == 'si'
        ? 'කෙසෙල් පළතුර තහවුරු විය'
        : (lang == 'ta' ? 'வாழைப்பழம் உறுதிப்படுத்தப்பட்டது' : 'Banana fruit confirmed');

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Reset un-scanned image state when popping/exiting screen
          ref.read(scanProvider.notifier).reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(scanProvider.notifier).reset();
              context.pop();
            },
          ),
          actions: [
            if (scanState.selectedImage != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: tooltipText,
                onPressed: _showImageSourceDialog,
              ),
          ],
        ),
        body: SafeArea(
          child: scanState.selectedImage == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, size: 72, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(noImageText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(captureBtnText),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(220, 48),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Uncropped Preview (BoxFit.contain)
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: scanState.selectedImageBytes != null
                            ? Image.memory(
                                scanState.selectedImageBytes!,
                                fit: BoxFit.contain, // NEVER cropped
                              )
                            : const SizedBox(),
                      ),
                      const SizedBox(height: 16),

                      // Real-time banana verification status
                      if (scanState.isCheckingBanana) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  checkingText,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Only display variety selection & Analyze Banana button once banana is confirmed
                      if (scanState.isBananaConfirmed) ...[
                        // Horizontally centered verified badge matching app theme
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF052E16).withOpacity(0.65),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF22C55E).withOpacity(0.4),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  verifiedBadgeText,
                                  style: const TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Variety auto-selected (Cavendish) — no UI dropdown needed
                        const SizedBox(height: 16),

                        // "Analyze" Button
                        ElevatedButton.icon(
                          onPressed: _proceedToAnalysis,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(analyzeBtnText),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
