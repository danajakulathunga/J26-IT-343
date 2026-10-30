import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  void _onSkip() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF266E4E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildSlideOne(),
                  _buildSlideTwo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Analyze Any Fruit (Screenshot 4)
  Widget _buildSlideOne() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // Top Image
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/onboarding_fruits.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _buildFallback(Icons.apple_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Bottom Content
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const Text(
                  'Analyze Any Fruit',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14472F),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Instantly detect quality, variety, and ripeness with advanced computer vision.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),

                // Page Indicator
                _buildPageIndicator(0),
                const SizedBox(height: 24),

                // Next Button
                _buildNextButton('Next'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: FruitAI Intelligence (Screenshot 5)
  Widget _buildSlideTwo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Emblem with Tractor Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF266E4E),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF266E4E).withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.agriculture_rounded,
                size: 42,
                color: Color(0xFF20583E),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Headline
          const Text(
            'FruitAI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF14472F),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI-Powered Fruit Intelligence',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // 3D Scanning Visual
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/onboarding_fruit_ai.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _buildFallback(Icons.blur_on_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Page Indicator
          _buildPageIndicator(1),
          const SizedBox(height: 24),

          // Get Started / Next Button
          _buildNextButton('Get Started'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 7,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF266E4E) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildNextButton(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF266E4E),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(IconData icon) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(icon, size: 56, color: const Color(0xFF266E4E)),
      ),
    );
  }
}
