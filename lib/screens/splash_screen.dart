import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateNext();
    });
  }

  Future<void> _navigateNext() async {
    // Show splash animation smoothly while restoring session concurrently
    final minSplashWait = Future.delayed(const Duration(milliseconds: 1400));

    // Await session restoration & validation (token refresh or cached profile / guest)
    final user = await ref.read(authProvider.notifier).checkCurrentUser();

    await minSplashWait;
    if (!mounted) return;

    final isFirstLaunch = storageService.isFirstLaunch();
    if (isFirstLaunch) {
      context.go('/onboarding-language');
      return;
    }

    if (user != null) {
      // User or Free Using guest is authenticated -> navigate directly to Home
      context.go('/home');
    } else {
      // Unauthenticated -> navigate to Sign In / Auth landing
      context.go('/auth-landing');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Layer 1: Base botanical gradient ──────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D5016), // Deep forest top-left
                  Color(0xFF1B5E20), // Brand green mid
                  Color(0xFF0F3D18), // Rich botanical dark bottom-right
                ],
                stops: [0.0, 0.50, 1.0],
              ),
            ),
          ),

          // ── Layer 2: Organic blob shapes (CustomPaint) ───────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _BotanicalBlobPainter(),
            ),
          ),

          // ── Layer 3: All existing content — untouched ─────────────────────
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Splash Screen Image — unchanged
                              Image.asset(
                                'assets/images/SplashScreen_Image.png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'BananaGuard AI',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Intelligent Defect & Disease Diagnostics',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 48),
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentYellow),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Splash Screen Footer — unchanged
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                    child: Text(
                      '© 2026 All rights reserved. Developed by DVK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botanical Organic Blob Painter ─────────────────────────────────────────────
// Large blurred organic circles positioned around the screen to give a
// botanical / leaf-texture depth effect that matches bg_image.jpg green tones.
// No animation, no external packages — pure Flutter CustomPainter.
class _BotanicalBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Blob 1 — Large light-green arc, top-left bleeding off-screen
    // Mimics the lighter foliage highlights at the top of bg_image.jpg
    _drawBlob(
      canvas,
      center: Offset(size.width * -0.08, size.height * 0.12),
      radiusX: size.width * 0.72,
      radiusY: size.width * 0.72,
      color: const Color(0xFF4CAF50),
      opacity: 0.14,
      blur: 70,
    );

    // Blob 2 — Dark botanical blob, top-right corner
    // Gives shadow depth similar to the dark foliage edges in bg_image.jpg
    _drawBlob(
      canvas,
      center: Offset(size.width * 1.12, size.height * 0.08),
      radiusX: size.width * 0.58,
      radiusY: size.width * 0.58,
      color: const Color(0xFF1A3A0D),
      opacity: 0.55,
      blur: 55,
    );

    // Blob 3 — Mid botanical oval, left-center
    // Adds organic mid-screen texture depth
    _drawBlob(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.52),
      radiusX: size.width * 0.55,
      radiusY: size.height * 0.22,
      color: const Color(0xFF558B2F),
      opacity: 0.18,
      blur: 65,
    );

    // Blob 4 — Warm banana-yellow subtle glow, center-bottom
    // The warm accent that ties to accentYellow and the warm light in bg_image
    _drawBlob(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.88),
      radiusX: size.width * 0.58,
      radiusY: size.width * 0.38,
      color: const Color(0xFFEAB308),
      opacity: 0.07,
      blur: 90,
    );

    // Blob 5 — Mid-green oval, bottom-right bleeding off-screen
    // Anchors the lower palette to match bg_image botanical lower tones
    _drawBlob(
      canvas,
      center: Offset(size.width * 1.08, size.height * 0.78),
      radiusX: size.width * 0.62,
      radiusY: size.height * 0.25,
      color: const Color(0xFF3B7A1A),
      opacity: 0.22,
      blur: 58,
    );

    // Blob 6 — Small bright accent blob, center-right mid
    // Adds a subtle luminosity highlight for depth
    _drawBlob(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.42),
      radiusX: size.width * 0.28,
      radiusY: size.width * 0.28,
      color: const Color(0xFF66BB6A),
      opacity: 0.10,
      blur: 45,
    );
  }

  void _drawBlob(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double opacity,
    required double blur,
  }) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
