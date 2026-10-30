import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _proceed() {
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      body: SafeArea(
        child: GestureDetector(
          onTap: _proceed,
          behavior: HitTestBehavior.opaque,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Top Field Kit Emblem
                          _buildSealBadge(),

                          const SizedBox(height: 18),

                          // Main Title
                          const Text(
                            'Ceylon Export\nField Kit',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 32,
                              height: 1.15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B4D36),
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Small Divider dot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 24, height: 1.2, color: const Color(0xFF8BAA96)),
                              const SizedBox(width: 6),
                              const Icon(Icons.circle, size: 5, color: Color(0xFF2C6B4B)),
                              const SizedBox(width: 6),
                              Container(width: 24, height: 1.2, color: const Color(0xFF8BAA96)),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36.0),
                            child: Text(
                              'AI quality grading & blockchain\ntraceability for Sri Lankan fruit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Center Banana Illustration
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 280),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1B4D36).withValues(alpha: 0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/splash_banana.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => _buildImageFallback(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Wave Stepper Card
                  _buildBottomCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSealBadge() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFAFCF8),
        border: Border.all(
          color: const Color(0xFF2A6848),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4D36).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'C',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4D36),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'EST. FIELD KIT',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D5940),
              ),
            ),
            const SizedBox(height: 2),
            const Icon(
              Icons.eco,
              size: 14,
              color: Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF163E2B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF88C59A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Heading
          const Text(
            'From Farm to Global Trust',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Smart. Transparent. Trusted.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),

          // 4 Icons Pipeline Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepIcon(Icons.eco_outlined),
              _buildArrow(),
              _buildStepIcon(Icons.inventory_2_outlined),
              _buildArrow(),
              _buildStepIcon(Icons.verified_user_outlined),
              _buildArrow(),
              _buildStepIcon(Icons.public_outlined),
            ],
          ),
          const SizedBox(height: 18),

          // Tap to Begin button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F5E9),
                foregroundColor: const Color(0xFF163E2B),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Icon(icon, color: const Color(0xFF90D5A3), size: 18),
    );
  }

  Widget _buildArrow() {
    return Icon(
      Icons.chevron_right,
      color: Colors.white.withValues(alpha: 0.4),
      size: 18,
    );
  }

  Widget _buildImageFallback() {
    return Container(
      height: 240,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.eco, size: 64, color: Color(0xFF2C6B4B)),
      ),
    );
  }
}
