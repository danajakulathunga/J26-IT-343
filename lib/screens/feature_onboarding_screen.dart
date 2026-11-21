import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';

/// The 5-Screen Feature Onboarding for BananaGuard AI.
///
/// Follows the botanical design system:
/// - Soft botanical cream (#F7F5DF)
/// - Pale yellow-green (#E8F0D9)
/// - Light mint green (#DCEFE5)
/// - Muted leaf green (#A8C88A)
/// - Primary dark green (#1B5E20)
/// - Deep forest green (#174C27)
/// - Soft white (#FFFFFF)
class FeatureOnboardingScreen extends StatefulWidget {
  const FeatureOnboardingScreen({super.key});

  @override
  State<FeatureOnboardingScreen> createState() =>
      _FeatureOnboardingScreenState();
}

class _FeatureOnboardingScreenState extends State<FeatureOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;

  static const Color colCream = Color(0xFFF7F5DF);
  static const Color colPaleYellowGreen = Color(0xFFE8F0D9);
  static const Color colLightMint = Color(0xFFDCEFE5);
  static const Color colMutedLeaf = Color(0xFFA8C88A);
  static const Color colPrimaryDarkGreen = Color(0xFF1B5E20);
  static const Color colDeepForest = Color(0xFF174C27);

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      number: '01',
      title: 'Detect Banana Defects & Diseases',
      description:
          'Identify visible banana defects and diseases through intelligent image analysis. Detect conditions such as black spots, bruising, fungal infections, bacterial infections, physical damage, shape abnormalities, and surface wrinkles.',
      tagline: 'Identify What Is Wrong With Your Banana',
      badge: 'AI-Powered Detection',
    ),
    _OnboardingItem(
      number: '02',
      title: 'Understand Disease Severity',
      description:
          'Evaluate the severity of detected banana defects and diseases. Understand whether the affected fruit condition is mild, moderate, or severe through visual assessment.',
      tagline: 'Know How Serious the Condition Is',
      badge: 'Visual Severity Index',
    ),
    _OnboardingItem(
      number: '03',
      title: 'Understand Possible Causes',
      description:
          'Explore possible contributing factors associated with detected banana diseases, including excessive moisture, poor ventilation, improper handling, contaminated tools, infected planting materials, and unsuitable storage conditions.',
      tagline: 'Discover Factors That May Contribute to Disease',
      badge: 'Risk Factor Analysis',
    ),
    _OnboardingItem(
      number: '04',
      title: 'Get Smart Prevention Recommendations',
      description:
          'Receive practical prevention and management recommendations based on the detected banana condition and its severity. Learn how to reduce disease risks and maintain better fruit quality.',
      tagline: 'Know What Actions Can Help Protect Fruit Quality',
      badge: 'Decision-Support Guidance',
    ),
    _OnboardingItem(
      number: '05',
      title: 'See How AI Makes Decisions',
      description:
          'Explore visual explanations of AI predictions and receive comprehensive analysis reports containing detected conditions, severity assessments, possible contributing factors, and prevention recommendations.',
      tagline: 'Understand the Results. Explore the Analysis.',
      badge: 'Explainable AI & Reports',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleFinish() async {
    await storageService.setFirstLaunchCompleted();
    if (!mounted) return;
    context.go('/auth-landing');
  }

  void _handleNext() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _handleFinish();
    }
  }

  void _handleBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Gradient & Botanical Leaf Silhouettes ──────────────
          const Positioned.fill(
            child: _BotanicalBackgroundPainterWidget(),
          ),

          // ── Main Content Area ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top Header Bar ──────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colMutedLeaf.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colDeepForest.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: colPrimaryDarkGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'BananaGuard AI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colDeepForest,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip Button
                      TextButton(
                        onPressed: _handleFinish,
                        style: TextButton.styleFrom(
                          foregroundColor: colDeepForest.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colDeepForest.withOpacity(0.85),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: colDeepForest.withOpacity(0.85),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Swipeable PageView ──────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildOnboardingPage(item, index, size);
                    },
                  ),
                ),

                // ── Bottom Navigation Controls ──────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                      24, 8, 24, bottomPadding > 0 ? bottomPadding : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: colMutedLeaf.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pagination Dots Indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_items.length, (i) {
                            final isActive = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colPrimaryDarkGreen
                                    : colMutedLeaf.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Navigation Buttons
                      Row(
                        children: [
                          // Back Button (hidden on first page)
                          if (_currentPage > 0) ...[
                            OutlinedButton(
                              onPressed: _handleBack,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colDeepForest,
                                side: BorderSide(
                                  color: colMutedLeaf.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.8),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Primary Action Button (Next / Get Started)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colPrimaryDarkGreen,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: colPrimaryDarkGreen.withOpacity(0.4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _items.length - 1
                                        ? 'Get Started'
                                        : 'Next',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _currentPage == _items.length - 1
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(
      _OnboardingItem item, int index, Size screenSize) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),

          // Illustration Viewport
          Container(
            width: double.infinity,
            height: screenSize.height * 0.38,
            constraints: const BoxConstraints(maxHeight: 330, minHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colPaleYellowGreen,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colDeepForest.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Botanical background glow
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colPaleYellowGreen.withOpacity(0.55),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colLightMint.withOpacity(0.55),
                      ),
                    ),
                  ),

                  // Screen-Specific Custom Illustration
                  _buildIllustration(index),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Key Tagline Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colLightMint.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colMutedLeaf.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: colPrimaryDarkGreen,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colDeepForest,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Screen Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colDeepForest,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 10),

          // Description Paragraph
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: colDeepForest.withOpacity(0.8),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildIllustration(int index) {
    switch (index) {
      case 0:
        return const _Screen1DefectDetectionIllustration();
      case 1:
        return const _Screen2SeverityAssessmentIllustration();
      case 2:
        return const _Screen3RiskFactorAnalysisIllustration();
      case 3:
        return const _Screen4PreventionRecommendationsIllustration();
      case 4:
        return const _Screen5ExplainableAIReportIllustration();
      default:
        return const SizedBox();
    }
  }
}

// ============================================================================
// MODEL
// ============================================================================
class _OnboardingItem {
  final String number;
  final String title;
  final String description;
  final String tagline;
  final String badge;

  const _OnboardingItem({
    required this.number,
    required this.title,
    required this.description,
    required this.tagline,
    required this.badge,
  });
}

// ============================================================================
// SCREEN 01: DEFECT & DISEASE DETECTION ILLUSTRATION
// ============================================================================
class _Screen1DefectDetectionIllustration extends StatelessWidget {
  const _Screen1DefectDetectionIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Banana & Inspection Canvas
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _BananaInspectionPainter(),
            ),

            // AI Reticle Viewfinder Corners
            Positioned(
              top: constraints.maxHeight * 0.16,
              left: constraints.maxWidth * 0.14,
              right: constraints.maxWidth * 0.14,
              bottom: constraints.maxHeight * 0.16,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Scanning Status Chip (Top-Center)
            Positioned(
              top: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.center_focus_strong,
                        size: 13, color: Color(0xFF1B5E20)),
                    SizedBox(width: 5),
                    Text(
                      'AI Multi-Spot Scan Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF174C27),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Defect Tag 1: Anthracnose Spot
            Positioned(
              top: constraints.maxHeight * 0.32,
              right: constraints.maxWidth * 0.08,
              child: _buildDefectPill(
                title: 'Anthracnose Spot',
                confidence: '97%',
                color: const Color(0xFFDC2626),
              ),
            ),

            // Defect Tag 2: Surface Bruising
            Positioned(
              bottom: constraints.maxHeight * 0.22,
              left: constraints.maxWidth * 0.08,
              child: _buildDefectPill(
                title: 'Surface Bruise',
                confidence: '89%',
                color: const Color(0xFFD97706),
              ),
            ),

            // Defect Tag 3: Healthy Tip
            Positioned(
              top: constraints.maxHeight * 0.22,
              left: constraints.maxWidth * 0.12,
              child: _buildDefectPill(
                title: 'Healthy Peel',
                confidence: '99%',
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefectPill({
    required String title,
    required String confidence,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              confidence,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BananaInspectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw stylized curved banana
    final bananaPath = Path();
    bananaPath.moveTo(cx - 75, cy + 35);
    bananaPath.cubicTo(
      cx - 40,
      cy + 75,
      cx + 45,
      cy + 65,
      cx + 85,
      cy - 20,
    );
    bananaPath.cubicTo(
      cx + 88,
      cy - 35,
      cx + 70,
      cy - 40,
      cx + 55,
      cy - 25,
    );
    bananaPath.cubicTo(
      cx + 25,
      cy + 30,
      cx - 35,
      cy + 30,
      cx - 70,
      cy + 20,
    );
    bananaPath.close();

    // Banana gradient body
    final bananaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFDE047), // Fresh banana yellow
          Color(0xFFEAB308), // Golden ripe
          Color(0xFFCA8A04), // Warm base
        ],
      ).createShader(Rect.fromLTWH(cx - 80, cy - 50, 170, 130));

    canvas.drawPath(bananaPath, bananaPaint);

    // Banana Peel Stem (Pedicel)
    final stemPaint = Paint()..color = const Color(0xFF65A30D);
    final stemPath = Path();
    stemPath.moveTo(cx - 75, cy + 35);
    stemPath.lineTo(cx - 88, cy + 42);
    stemPath.lineTo(cx - 85, cy + 48);
    stemPath.lineTo(cx - 70, cy + 38);
    stemPath.close();
    canvas.drawPath(stemPath, stemPaint);

    // Visible Defects on the Banana
    // 1. Anthracnose spots (dark brown with yellow halo)
    final haloPaint = Paint()..color = const Color(0xFFFEF08A);
    final spotPaint = Paint()..color = const Color(0xFF451A03);

    // Cluster 1
    canvas.drawCircle(Offset(cx + 25, cy + 28), 6, haloPaint);
    canvas.drawCircle(Offset(cx + 25, cy + 28), 4, spotPaint);
    canvas.drawCircle(Offset(cx + 34, cy + 22), 4, haloPaint);
    canvas.drawCircle(Offset(cx + 34, cy + 22), 2.5, spotPaint);

    // Cluster 2: Surface bruise
    final bruisePaint = Paint()
      ..color = const Color(0xFF78350F).withOpacity(0.55);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 15, cy + 38), width: 22, height: 10),
      bruisePaint,
    );

    // Cluster 3: Crown speckles
    canvas.drawCircle(Offset(cx + 60, cy - 8), 3, spotPaint);
    canvas.drawCircle(Offset(cx + 68, cy - 16), 2.5, spotPaint);

    // Magnifying Glass over Defect
    final glassCenter = Offset(cx + 28, cy + 26);
    final glassRadius = 26.0;

    // Glass rim shadow
    canvas.drawCircle(
      glassCenter,
      glassRadius + 3,
      Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Glass rim
    canvas.drawCircle(
      glassCenter,
      glassRadius,
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Glass lens reflection
    canvas.drawCircle(
      glassCenter,
      glassRadius - 2,
      Paint()..color = const Color(0xFFE8F0D9).withOpacity(0.35),
    );

    // Magnifying glass handle
    final handlePaint = Paint()
      ..color = const Color(0xFF174C27)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(glassCenter.dx + glassRadius * 0.7,
          glassCenter.dy + glassRadius * 0.7),
      Offset(glassCenter.dx + glassRadius * 1.5,
          glassCenter.dy + glassRadius * 1.5),
      handlePaint,
    );

    // Crosshairs inside magnifier
    final reticlePaint = Paint()
      ..color = const Color(0xFF1B5E20).withOpacity(0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(glassCenter.dx - 8, glassCenter.dy),
      Offset(glassCenter.dx + 8, glassCenter.dy),
      reticlePaint,
    );
    canvas.drawLine(
      Offset(glassCenter.dx, glassCenter.dy - 8),
      Offset(glassCenter.dx, glassCenter.dy + 8),
      reticlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// SCREEN 02: SEVERITY ASSESSMENT ILLUSTRATION
// ============================================================================
class _Screen2SeverityAssessmentIllustration extends StatelessWidget {
  const _Screen2SeverityAssessmentIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header comparison
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFA8C88A).withOpacity(0.4)),
            ),
            child: const Text(
              'Comparative Visual Severity Assessment',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF174C27),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Severity Comparison Bananas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeverityCard(
                stage: 'Mild',
                percentage: '6%',
                color: const Color(0xFF16A34A),
                description: 'Minor Spotting',
                defectSeverity: 0.15,
              ),
              _buildSeverityCard(
                stage: 'Moderate',
                percentage: '34%',
                color: const Color(0xFFD97706),
                description: 'Active Lesions',
                defectSeverity: 0.45,
              ),
              _buildSeverityCard(
                stage: 'Severe',
                percentage: '78%',
                color: const Color(0xFFDC2626),
                description: 'Heavy Necrosis',
                defectSeverity: 0.85,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Severity Meter Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFA8C88A).withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Affected Surface Index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF174C27),
                      ),
                    ),
                    Text(
                      '3-Tier Classification',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Gradient bar with ticks
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF16A34A), // Mild
                          Color(0xFFEAB308), // Light amber
                          Color(0xFFD97706), // Moderate
                          Color(0xFFDC2626), // Severe
                        ],
                        stops: [0.0, 0.35, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0% Mild',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A))),
                    Text('30% Moderate',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706))),
                    Text('70%+ Severe',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityCard({
    required String stage,
    required String percentage,
    required Color color,
    required String description,
    required double defectSeverity,
  }) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mini Banana Graphic with corresponding defects
          SizedBox(
            width: 70,
            height: 48,
            child: CustomPaint(
              painter: _MiniSeverityBananaPainter(severity: defectSeverity),
            ),
          ),
          const SizedBox(height: 6),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stage,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSeverityBananaPainter extends CustomPainter {
  final double severity; // 0.15 = mild, 0.45 = moderate, 0.85 = severe

  _MiniSeverityBananaPainter({required this.severity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bananaPath = Path();
    bananaPath.moveTo(cx - 28, cy + 12);
    bananaPath.cubicTo(
      cx - 15,
      cy + 25,
      cx + 15,
      cy + 20,
      cx + 30,
      cy - 8,
    );
    bananaPath.cubicTo(
      cx + 31,
      cy - 14,
      cx + 22,
      cy - 16,
      cx + 18,
      cy - 10,
    );
    bananaPath.cubicTo(
      cx + 8,
      cy + 8,
      cx - 12,
      cy + 10,
      cx - 26,
      cy + 6,
    );
    bananaPath.close();

    final paint = Paint()
      ..color = severity > 0.7
          ? const Color(0xFFCA8A04)
          : const Color(0xFFFACC15);
    canvas.drawPath(bananaPath, paint);

    // Draw defect patches based on severity
    final defectPaint = Paint()..color = const Color(0xFF451A03);

    if (severity < 0.3) {
      // Mild: 2 tiny specks
      canvas.drawCircle(Offset(cx + 8, cy + 9), 1.8, defectPaint);
      canvas.drawCircle(Offset(cx + 14, cy + 4), 1.2, defectPaint);
    } else if (severity < 0.6) {
      // Moderate: several distinct spots
      canvas.drawCircle(Offset(cx + 6, cy + 8), 3.0, defectPaint);
      canvas.drawCircle(Offset(cx + 12, cy + 3), 2.5, defectPaint);
      canvas.drawCircle(Offset(cx - 2, cy + 12), 2.2, defectPaint);
    } else {
      // Severe: heavy overlapping dark lesions
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 8, cy + 6), width: 14, height: 8),
        defectPaint,
      );
      canvas.drawCircle(Offset(cx + 20, cy - 3), 3.5, defectPaint);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 8, cy + 11), width: 10, height: 6),
        defectPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// SCREEN 03: RISK FACTOR & CAUSE ANALYSIS ILLUSTRATION
// ============================================================================
class _Screen3RiskFactorAnalysisIllustration extends StatelessWidget {
  const _Screen3RiskFactorAnalysisIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Connector Web
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _RiskFactorWebPainter(),
            ),

            // Center Affected Banana Hub
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1B5E20),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withOpacity(0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.crisis_alert_rounded,
                      size: 26, color: Color(0xFFDC2626)),
                  SizedBox(height: 2),
                  Text(
                    'Affected\nFruit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF174C27),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            // 6 Risk Factors Arranged Orbitally
            // 1. Top-Left: Excessive Moisture & Humidity
            Positioned(
              top: 14,
              left: 14,
              child: _buildRiskFactorChip(
                icon: Icons.water_drop_rounded,
                label: 'High Humidity',
                detail: 'Excess Moisture',
                color: const Color(0xFF0284C7),
              ),
            ),

            // 2. Top-Right: Poor Ventilation
            Positioned(
              top: 14,
              right: 14,
              child: _buildRiskFactorChip(
                icon: Icons.air_rounded,
                label: 'Poor Airflow',
                detail: 'Stagnant Space',
                color: const Color(0xFF0D9488),
              ),
            ),

            // 3. Middle-Left: Rough Handling
            Positioned(
              top: cy - 20,
              left: 6,
              child: _buildRiskFactorChip(
                icon: Icons.pan_tool_alt_rounded,
                label: 'Rough Handling',
                detail: 'Impact Bruising',
                color: const Color(0xFFD97706),
              ),
            ),

            // 4. Middle-Right: Contaminated Tools
            Positioned(
              top: cy - 20,
              right: 6,
              child: _buildRiskFactorChip(
                icon: Icons.content_cut_rounded,
                label: 'Unclean Tools',
                detail: 'Pathogen Transfer',
                color: const Color(0xFFE11D48),
              ),
            ),

            // 5. Bottom-Left: Unsuitable Storage
            Positioned(
              bottom: 12,
              left: 14,
              child: _buildRiskFactorChip(
                icon: Icons.warehouse_rounded,
                label: 'Warm Storage',
                detail: '>28°C Unregulated',
                color: const Color(0xFF7C3AED),
              ),
            ),

            // 6. Bottom-Right: Infected Planting Materials
            Positioned(
              bottom: 12,
              right: 14,
              child: _buildRiskFactorChip(
                icon: Icons.grass_rounded,
                label: 'Infected Suckers',
                detail: 'Planting Stock',
                color: const Color(0xFF15803D),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRiskFactorChip({
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskFactorWebPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final linePaint = Paint()
      ..color = const Color(0xFFA8C88A).withOpacity(0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Curved connector lines from center to nodes
    final targets = [
      Offset(size.width * 0.25, size.height * 0.16),
      Offset(size.width * 0.75, size.height * 0.16),
      Offset(size.width * 0.18, cy),
      Offset(size.width * 0.82, cy),
      Offset(size.width * 0.25, size.height * 0.84),
      Offset(size.width * 0.75, size.height * 0.84),
    ];

    for (final target in targets) {
      final path = Path();
      path.moveTo(cx, cy);
      final midX = (cx + target.dx) / 2;
      final midY = (cy + target.dy) / 2;
      path.quadraticBezierTo(midX + 6, midY - 6, target.dx, target.dy);
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// SCREEN 04: PREVENTION & MANAGEMENT RECOMMENDATIONS ILLUSTRATION
// ============================================================================
class _Screen4PreventionRecommendationsIllustration extends StatelessWidget {
  const _Screen4PreventionRecommendationsIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual Separation Demo: Healthy Bunch vs Separated Fruit
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFA8C88A).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Healthy Bunch
                const Column(
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 24, color: Color(0xFF16A34A)),
                    SizedBox(height: 2),
                    Text(
                      'Healthy Harvest',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      'Clean & Protected',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                // Physical Barrier / Separation Indicator
                Container(
                  height: 38,
                  width: 1.5,
                  color: const Color(0xFFA8C88A).withOpacity(0.5),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0D9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare_arrows_rounded,
                          size: 12, color: Color(0xFF1B5E20)),
                      SizedBox(width: 2),
                      Text(
                        'Isolate',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 38,
                  width: 1.5,
                  color: const Color(0xFFA8C88A).withOpacity(0.5),
                ),

                // Affected Fruit Quarantined
                const Column(
                  children: [
                    Icon(Icons.rule_folder_rounded,
                        size: 24, color: Color(0xFFD97706)),
                    SizedBox(height: 2),
                    Text(
                      'Affected Fruit',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    Text(
                      'Separated for Safety',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Checklist Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1B5E20).withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checklist_rounded,
                        size: 15, color: Color(0xFF1B5E20)),
                    SizedBox(width: 6),
                    Text(
                      'Management Recommendations Checklist',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF174C27),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildChecklistItem(
                  icon: Icons.cleaning_services_rounded,
                  text: 'Maintain strict tool & crate sanitation',
                  color: const Color(0xFF15803D),
                ),
                _buildChecklistItem(
                  icon: Icons.air_rounded,
                  text: 'Improve storage ventilation & airflow',
                  color: const Color(0xFF0284C7),
                ),
                _buildChecklistItem(
                  icon: Icons.call_split_rounded,
                  text: 'Immediately separate affected fruit bunches',
                  color: const Color(0xFFD97706),
                ),
                _buildChecklistItem(
                  icon: Icons.thermostat_rounded,
                  text: 'Regulate cool storage temperature (13–14°C)',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              size: 14, color: Color(0xFF16A34A)),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 05: EXPLAINABLE AI & REPORT VIEW ILLUSTRATION
// ============================================================================
class _Screen5ExplainableAIReportIllustration extends StatelessWidget {
  const _Screen5ExplainableAIReportIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dual Panel: AI Heatmap View + Diagnostic Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heatmap Visual Card (Grad-CAM style)
              Expanded(
                flex: 4,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banana outline with simulated heatmap
                      CustomPaint(
                        painter: _GradCamHeatmapPainter(),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility_rounded,
                                  size: 9, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'Grad-CAM Heatmap',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Classification & Metrics Panel
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Detected Defect Header
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFA8C88A).withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Primary Defect',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '97.4%',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Anthracnose Spot',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF174C27),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Severity Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFD97706).withOpacity(0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 10, color: Color(0xFFD97706)),
                                SizedBox(width: 3),
                                Text(
                                  'Moderate Severity (32%)',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Contributing Factors Quick Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0D9).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hub_rounded,
                              size: 11, color: Color(0xFF1B5E20)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Factors: High Humidity, Warm Storage',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF174C27),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Sequential Progression & AI Summary Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFA8C88A).withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCEFE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timeline_rounded,
                      size: 14, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sequential Tracking Available',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF174C27),
                        ),
                      ),
                      Text(
                        'Track progression: Improving, Stable, or Worsening',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Export PDF',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
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

class _GradCamHeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Stylized banana curve
    final bananaPath = Path();
    bananaPath.moveTo(cx - 38, cy + 18);
    bananaPath.cubicTo(
      cx - 20,
      cy + 36,
      cx + 20,
      cy + 30,
      cx + 40,
      cy - 12,
    );
    bananaPath.cubicTo(
      cx + 42,
      cy - 20,
      cx + 30,
      cy - 22,
      cx + 24,
      cy - 14,
    );
    bananaPath.cubicTo(
      cx + 10,
      cy + 10,
      cx - 16,
      cy + 14,
      cx - 35,
      cy + 10,
    );
    bananaPath.close();

    // Base banana fill
    canvas.drawPath(
      bananaPath,
      Paint()..color = const Color(0xFFFDE047),
    );

    // Simulated Heatmap Overlays (Saliency Map Activation)
    // Red core (Highest neural attribution)
    canvas.drawCircle(
      Offset(cx + 8, cy + 14),
      12,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Yellow middle zone
    canvas.drawCircle(
      Offset(cx + 6, cy + 12),
      18,
      Paint()
        ..color = const Color(0xFFF59E0B).withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Cyan/Blue boundary zone (Low activation)
    canvas.drawCircle(
      Offset(cx + 4, cy + 10),
      26,
      Paint()
        ..color = const Color(0xFF06B6D4).withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Defect focal point
    canvas.drawCircle(
      Offset(cx + 9, cy + 15),
      3,
      Paint()..color = const Color(0xFF7F1D1D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// BOTANICAL LEAF BACKGROUND PAINTER
// ============================================================================
class _BotanicalBackgroundPainterWidget extends StatelessWidget {
  const _BotanicalBackgroundPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BotanicalLeafSilhouettePainter(),
    );
  }
}

class _BotanicalLeafSilhouettePainter extends CustomPainter {
  static const Color colCream = Color(0xFFF7F5DF);
  static const Color colPaleYellowGreen = Color(0xFFE8F0D9);
  static const Color colLightMint = Color(0xFFDCEFE5);
  static const Color colMutedLeaf = Color(0xFFA8C88A);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle smooth gradient background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colCream,
          colPaleYellowGreen,
          colLightMint,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Large curved banana leaf silhouettes on edges
    final leafPaint1 = Paint()
      ..color = colMutedLeaf.withOpacity(0.14)
      ..style = PaintingStyle.fill;

    // Top-left curved banana leaf
    final leaf1 = Path();
    leaf1.moveTo(-20, -20);
    leaf1.cubicTo(
      size.width * 0.45,
      size.height * 0.05,
      size.width * 0.35,
      size.height * 0.28,
      -20,
      size.height * 0.22,
    );
    leaf1.close();
    canvas.drawPath(leaf1, leafPaint1);

    // Veins on top-left leaf
    final veinPaint = Paint()
      ..color = colMutedLeaf.withOpacity(0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(-10, -10),
      Offset(size.width * 0.25, size.height * 0.16),
      veinPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.06),
      Offset(size.width * 0.22, size.height * 0.05),
      veinPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.10),
      Offset(size.width * 0.28, size.height * 0.11),
      veinPaint,
    );

    // Bottom-right sweeping leaf silhouette
    final leafPaint2 = Paint()
      ..color = colMutedLeaf.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    final leaf2 = Path();
    leaf2.moveTo(size.width + 20, size.height + 20);
    leaf2.cubicTo(
      size.width * 0.55,
      size.height * 0.90,
      size.width * 0.65,
      size.height * 0.70,
      size.width + 20,
      size.height * 0.76,
    );
    leaf2.close();
    canvas.drawPath(leaf2, leafPaint2);

    canvas.drawLine(
      Offset(size.width + 10, size.height + 10),
      Offset(size.width * 0.72, size.height * 0.81),
      veinPaint,
    );

    // Soft organic translucent circle accent in center-right
    final circlePaint = Paint()
      ..color = colPaleYellowGreen.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.42),
      70,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

