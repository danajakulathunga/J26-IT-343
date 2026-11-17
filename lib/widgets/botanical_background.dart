import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bananaguard_ai/core/constants.dart';

/// A premium botanical background with graceful, stylized banana leaf branches
/// ("kesel kola") originating from the screen corners (top-left & bottom-right).
///
/// Features a gentle, natural tropical wind breeze animation ("hulangata selawena")
/// with out-of-phase organic swaying for a living botanical feel, while
/// preserving theme-adaptive palettes between Light and Dark modes.
class BotanicalBackground extends StatefulWidget {
  final Widget child;

  const BotanicalBackground({
    super.key,
    required this.child,
  });

  @override
  State<BotanicalBackground> createState() => _BotanicalBackgroundState();
}

class _BotanicalBackgroundState extends State<BotanicalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breezeController;

  @override
  void initState() {
    super.initState();
    // Smooth 5.5-second continuous wind breeze cycle
    _breezeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat();
  }

  @override
  void dispose() {
    _breezeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Vibrant Organic Base Gradient (Preserved) ────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF06180D), // Deep botanical night
                        Color(0xFF0B2414), // Emerald dark forest
                        Color(0xFF071A0E), // Forest floor tint
                      ]
                    : const [
                        Color(0xFFE2F0D9), // Distinct fresh banana-leaf tint (top)
                        Color(0xFFEFF7EE), // Soft luminous organic surface (mid)
                        Color(0xFFE5F3DC), // Fresh tropical garden tint (bottom)
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── Layer 2: Animated Swaying Leaf Branches ───────────────────────
        // RepaintBoundary isolates canvas repaints to Layer 2 only.
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _breezeController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BotanicalShapesPainter(
                    isDark: isDark,
                    animationValue: _breezeController.value,
                  ),
                );
              },
            ),
          ),
        ),

        // ── Layer 3: Screen Content (Never rebuilds from animation) ───────
        widget.child,
      ],
    );
  }
}

class _BotanicalShapesPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;

  _BotanicalShapesPainter({
    required this.isDark,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Ambient Lighting Glow Blobs (Preserved) ───────────────────────
    _drawAmbientGlows(canvas, size);

    // ── 2. Palette Definitions for Corner Foliage ────────────────────────
    final primaryLeafFill = isDark
        ? const Color(0xFF22C55E).withOpacity(0.24)
        : const Color(0xFF2E7D32).withOpacity(0.22);

    final secondaryLeafFill = isDark
        ? const Color(0xFF15803D).withOpacity(0.16)
        : const Color(0xFF388E3C).withOpacity(0.14);

    final leafStroke = isDark
        ? const Color(0xFF4ADE80).withOpacity(0.65)
        : const Color(0xFF1B5E20).withOpacity(0.55);

    final stemColor = isDark
        ? const Color(0xFF86EFAC).withOpacity(0.70)
        : const Color(0xFF1B5E20).withOpacity(0.60);

    // ── 3. Organic Wind Sway Calculation (Hulangata Selawena Effect) ─────
    final cycle = animationValue * 2 * math.pi;

    // Top-Left branch sway (gentle breeze arc ±0.038 rad / ~2.2°)
    final swayTop = math.sin(cycle) * 0.038 + math.sin(cycle * 2) * 0.010;

    // Bottom-Right branch sway (out-of-phase for a natural passing wind gust)
    final swayBottom = math.sin(cycle + 1.35) * 0.035 + math.cos(cycle * 2) * 0.008;

    // ── 4. Corner 1: Top of Left Side (Top-Left Branch with Breeze) ──────
    _drawBotanicalCornerBranch(
      canvas,
      origin: Offset(-size.width * 0.04, -size.height * 0.02),
      angle: 2.38 + swayTop,
      swayFlutter: swayTop,
      length: size.height * 0.38,
      primaryFill: primaryLeafFill,
      secondaryFill: secondaryLeafFill,
      strokeColor: leafStroke,
      stemColor: stemColor,
    );

    // ── 5. Corner 2: Bottom of Right Side (Bottom-Right Branch with Breeze)
    _drawBotanicalCornerBranch(
      canvas,
      origin: Offset(size.width * 1.04, size.height * 1.02),
      angle: -0.80 + swayBottom,
      swayFlutter: swayBottom,
      length: size.height * 0.42,
      primaryFill: primaryLeafFill,
      secondaryFill: secondaryLeafFill,
      strokeColor: leafStroke,
      stemColor: stemColor,
    );
  }

  /// Draws a graceful botanical branch with layered banana/frond leaves.
  /// Individual leaves flutter subtly in proportion to wind intensity.
  void _drawBotanicalCornerBranch(
    Canvas canvas, {
    required Offset origin,
    required double angle,
    required double swayFlutter,
    required double length,
    required Color primaryFill,
    required Color secondaryFill,
    required Color strokeColor,
    required Color stemColor,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);

    // Dynamic curved stem spine that flexes slightly with the wind
    final stemPath = Path();
    stemPath.moveTo(0, 0);
    stemPath.cubicTo(
      -length * 0.06 + swayFlutter * 15, -length * 0.35,
      length * 0.04 + swayFlutter * 25, -length * 0.70,
      swayFlutter * 30, -length,
    );

    // ── Layer A: Background Leaves (Drawn first for depth) ───────────────
    // 1. Lower lateral leaf (pointing left-outward)
    _drawFrondLeaf(
      canvas,
      base: Offset(-length * 0.02, -length * 0.18),
      length: length * 0.42,
      width: length * 0.12,
      angle: -0.65 + swayFlutter * 0.35,
      fillColor: secondaryFill,
      strokeColor: strokeColor.withOpacity(strokeColor.opacity * 0.8),
    );

    // 2. Lower-mid lateral leaf (pointing right-outward)
    _drawFrondLeaf(
      canvas,
      base: Offset(-length * 0.03, -length * 0.32),
      length: length * 0.46,
      width: length * 0.13,
      angle: 0.60 - swayFlutter * 0.40,
      fillColor: secondaryFill,
      strokeColor: strokeColor.withOpacity(strokeColor.opacity * 0.8),
    );

    // 3. Mid lateral leaf (pointing left-outward)
    _drawFrondLeaf(
      canvas,
      base: Offset(0, -length * 0.48),
      length: length * 0.48,
      width: length * 0.13,
      angle: -0.52 + swayFlutter * 0.50,
      fillColor: secondaryFill,
      strokeColor: strokeColor.withOpacity(strokeColor.opacity * 0.85),
    );

    // ── Layer B: Foreground Leaves (Richer tone & crisp lines) ───────────
    // 4. Mid-high lateral leaf (pointing right-upward)
    _drawFrondLeaf(
      canvas,
      base: Offset(length * 0.02, -length * 0.62),
      length: length * 0.44,
      width: length * 0.12,
      angle: 0.48 - swayFlutter * 0.55,
      fillColor: primaryFill,
      strokeColor: strokeColor,
    );

    // 5. High lateral leaf (pointing left-upward)
    _drawFrondLeaf(
      canvas,
      base: Offset(length * 0.01, -length * 0.76),
      length: length * 0.38,
      width: length * 0.11,
      angle: -0.38 + swayFlutter * 0.65,
      fillColor: primaryFill,
      strokeColor: strokeColor,
    );

    // 6. Sub-terminal leaf (pointing right-upward)
    _drawFrondLeaf(
      canvas,
      base: Offset(0, -length * 0.88),
      length: length * 0.32,
      width: length * 0.09,
      angle: 0.28 - swayFlutter * 0.70,
      fillColor: primaryFill,
      strokeColor: strokeColor,
    );

    // 7. Terminal crowning tip leaf (flexes most at branch tip)
    _drawFrondLeaf(
      canvas,
      base: Offset(0, -length * 0.95),
      length: length * 0.34,
      width: length * 0.09,
      angle: 0.0 + swayFlutter * 0.85,
      fillColor: primaryFill,
      strokeColor: strokeColor,
    );

    // ── Central Stem Stalk ───────────────────────────────────────────────
    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stemPath, stemPaint);

    canvas.restore();
  }

  /// Draws a single lanceolate banana/frond leaf with smooth natural curvature,
  /// translucent fill, perimeter outline, and delicate central midrib.
  void _drawFrondLeaf(
    Canvas canvas, {
    required Offset base,
    required double length,
    required double width,
    required double angle,
    required Color fillColor,
    required Color strokeColor,
  }) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);

    final path = Path();
    path.moveTo(0, 0);

    // Left blade contour
    path.cubicTo(
      -width * 0.48, -length * 0.26,
      -width * 0.54, -length * 0.68,
      0, -length,
    );

    // Right blade contour
    path.cubicTo(
      width * 0.54, -length * 0.68,
      width * 0.48, -length * 0.26,
      0, 0,
    );
    path.close();

    // 1. Leaf Blade Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Leaf Perimeter Stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // 3. Delicate Central Midrib Spine
    final midrib = Path();
    midrib.moveTo(0, 0);
    midrib.quadraticBezierTo(0, -length * 0.50, 0, -length * 0.94);
    canvas.drawPath(
      midrib,
      strokePaint
        ..strokeWidth = 1.3
        ..color = strokeColor.withOpacity(strokeColor.opacity * 0.85),
    );

    canvas.restore();
  }

  void _drawAmbientGlows(Canvas canvas, Size size) {
    // Top-Left Botanical Emerald Glow
    _drawGlowSphere(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.10),
      radius: size.width * 0.48,
      color: isDark ? const Color(0xFF15803D) : const Color(0xFF2E7D32),
      opacity: isDark ? 0.35 : 0.20,
      blur: 70,
    );

    // Top-Right Warm Banana Yellow Glow
    _drawGlowSphere(
      canvas,
      center: Offset(size.width * 0.92, size.height * 0.08),
      radius: size.width * 0.44,
      color: AppConstants.accentYellow,
      opacity: isDark ? 0.28 : 0.18,
      blur: 75,
    );

    // Mid-Left Forest Green Glow
    _drawGlowSphere(
      canvas,
      center: Offset(size.width * 0.10, size.height * 0.48),
      radius: size.width * 0.42,
      color: const Color(0xFF1B5E20),
      opacity: isDark ? 0.30 : 0.16,
      blur: 65,
    );

    // Mid-Right Sunlit Yellow Glow
    _drawGlowSphere(
      canvas,
      center: Offset(size.width * 0.90, size.height * 0.55),
      radius: size.width * 0.40,
      color: const Color(0xFFEAB308),
      opacity: isDark ? 0.25 : 0.15,
      blur: 70,
    );

    // Bottom-Right Deep Lush Forest Glow
    _drawGlowSphere(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.86),
      radius: size.width * 0.50,
      color: isDark ? const Color(0xFF166534) : const Color(0xFF388E3C),
      opacity: isDark ? 0.35 : 0.20,
      blur: 75,
    );
  }

  void _drawGlowSphere(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
    required double blur,
  }) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _BotanicalShapesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}
