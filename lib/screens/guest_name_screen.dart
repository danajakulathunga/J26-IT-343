import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/auth_provider.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';

class GuestNameScreen extends ConsumerStatefulWidget {
  const GuestNameScreen({super.key});

  @override
  ConsumerState<GuestNameScreen> createState() => _GuestNameScreenState();
}

class _GuestNameScreenState extends ConsumerState<GuestNameScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final success = await ref.read(authProvider.notifier).loginAsGuest(name);

    if (success && mounted) {
      context.go('/home');
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(
        fontSize: 14.5,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14.5,
        color: AppConstants.primaryGreen,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF94A3B8),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(
          prefixIcon,
          color: AppConstants.primaryGreen,
          size: 22,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppConstants.primaryGreen, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppConstants.severitySevere, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppConstants.severitySevere, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).languageCode;

    final appTitle = lang == 'si'
        ? 'අමුත්තන්ගේ මාදිලිය'
        : (lang == 'ta' ? 'விருந்தினர் பயன்முறை' : 'Guest Mode');
    final headingText = lang == 'si'
        ? 'ඔබගේ නම කුමක්ද?'
        : (lang == 'ta' ? 'உங்கள் பெயர் என்ன?' : 'What is your name?');
    final subText = lang == 'si'
        ? 'ඔබගේ නම වාර්තා සහ මුල් පිටුව සඳහා භාවිත වේ. විද්‍යුත් තැපෑලක් හෝ මුරපදයක් අවශ්‍ය නොවේ!'
        : (lang == 'ta'
            ? 'உங்கள் பெயர் அறிக்கைகள் மற்றும் முகப்பு வாழ்த்துகளுக்கு பயன்படுத்தப்படும். மின்னஞ்சல் அல்லது கடவுச்சொல் தேவையில்லை!'
            : 'Your name will be personalized in diagnostic reports and dashboard greetings. No email or password needed!');
    final labelName = lang == 'si'
        ? 'ඔබගේ නම'
        : (lang == 'ta' ? 'உங்கள் பெயர்' : 'Your Name');
    final hintName = lang == 'si'
        ? 'උදා. කසුන් / නිමල්'
        : (lang == 'ta' ? 'எ.கா. கசுன் / நிமால்' : 'e.g. Kasun / Nimal');
    final validatorMsg = lang == 'si'
        ? 'ඉදිරියට යාමට කරුණාකර ඔබගේ නම ඇතුළත් කරන්න'
        : (lang == 'ta' ? 'தொடர உங்கள் பெயரை உள்ளிடவும்' : 'Please enter your name to proceed');
    final startBtnText = lang == 'si'
        ? 'පරීක්ෂාව අරඹන්න'
        : (lang == 'ta' ? 'ஸ்கேன் செய்யத் தொடங்குங்கள்' : 'Start Scanning');

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen background image (always fully displayed during and after animation)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // 2. Full-screen botanical gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.28, 0.55, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.55),
                    AppConstants.primaryGreen.withOpacity(0.68),
                    AppConstants.primaryGreen.withOpacity(0.35),
                    Colors.black.withOpacity(0.20),
                  ],
                ),
              ),
            ),
          ),

          // 3. Foreground Content: Header at top + Slide-Up Animated Form Card at bottom
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header branding & title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 46, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on_rounded, size: 14, color: AppConstants.accentYellow),
                            SizedBox(width: 5),
                            Text(
                              'Instant Free Access',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        appTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quick diagnostics without account registration',
                        style: TextStyle(
                          fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Slide-Up Animated White Card containing the guest form (anchored to bottom)
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 18,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headingText,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Full Name field
                              TextFormField(
                                controller: _nameController,
                                autofocus: true,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: _buildInputDecoration(
                                  labelText: labelName,
                                  hintText: hintName,
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return validatorMsg;
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _continue(),
                              ),
                              const SizedBox(height: 28),

                              // Start Scanning Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _continue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: AppConstants.primaryGreen.withOpacity(0.35),
                                  minimumSize: const Size(double.infinity, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(startBtnText),
                              ),
                              const SizedBox(height: 16),

                              // Switch to Sign In / Sign Up
                              Center(
                                child: TextButton(
                                  onPressed: () => context.pushReplacement('/sign-in'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppConstants.primaryGreen,
                                  ),
                                  child: const Text(
                                    'Have an account? Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Pinned Top Navigation Bar (Back button)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
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
}
