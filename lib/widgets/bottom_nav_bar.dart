import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/notifications_provider.dart';
import 'package:bananaguard_ai/widgets/scan_fab.dart';

class CustomBottomNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final Function(int) onTapIndex;
  final VoidCallback onScanPressed;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapIndex,
    required this.onScanPressed,
  });

  @override
  ConsumerState<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends ConsumerState<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Slowly pulsating green light animation (2.6s cycle)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = ref.watch(notificationProvider.select((s) => s.unreadCount));

    final barBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final lang = Localizations.localeOf(context).languageCode;
    String homeLabel = 'Home';
    String historyLabel = 'History';
    String alertsLabel = 'Alerts';
    String profileLabel = 'Profile';

    if (lang == 'si') {
      homeLabel = 'මුල් පිටුව';
      historyLabel = 'ඉතිහාසය';
      alertsLabel = 'දැනුම්දීම්';
      profileLabel = 'ගිණුම';
    } else if (lang == 'ta') {
      homeLabel = 'முகப்பு';
      historyLabel = 'வரலாறு';
      alertsLabel = 'அறிவிப்புகள்';
      profileLabel = 'சுயவிவரம்';
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const navBarContentHeight = 75.0; // Increased navbar height for better aesthetics & ergonomics
    final barHeight = navBarContentHeight + bottomPadding;
    // totalHeight equals barHeight so body content extends right to the top of the navbar (gap eliminated)
    final totalHeight = barHeight;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Edge-to-edge navbar body with curved top corners & center curved notch
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight,
            child: CustomPaint(
              painter: _CurvedNavBarPainter(
                backgroundColor: barBg,
                borderColor: borderColor,
                shadowColor: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : const Color(0xFF0F172A).withValues(alpha: 0.08),
                notchRadius: 42.0,
                notchCenterY: 12.0,
                cornerRadius: 24.0,
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: SizedBox(
                  height: navBarContentHeight,
                  child: Row(
                    children: [
                      // Left 2 Navigation Items
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: homeLabel,
                          isSelected: widget.currentIndex == 0,
                          onTap: () => widget.onTapIndex(0),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.history_rounded,
                          activeIcon: Icons.history_rounded,
                          label: historyLabel,
                          isSelected: widget.currentIndex == 1,
                          onTap: () => widget.onTapIndex(1),
                        ),
                      ),

                      // Center breathing space aligned with curved notch
                      const SizedBox(width: 84),

                      // Right 2 Navigation Items
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.notifications_none_rounded,
                          activeIcon: Icons.notifications_rounded,
                          label: alertsLabel,
                          isSelected: widget.currentIndex == 2,
                          badgeCount: unreadCount,
                          onTap: () => widget.onTapIndex(2),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: profileLabel,
                          isSelected: widget.currentIndex == 3,
                          onTap: () => widget.onTapIndex(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Center Camera Button: Exact position maintained inside notch with radiant green glow
          Positioned(
            top: -24, // Sits precisely in notch (center at y=12, perfectly aligned with notchCenterY=12)
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                final v = _glowAnimation.value;
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: barBg,
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      width: 2.0,
                    ),
                    boxShadow: [
                      // Slowly diffusing green light bloom (gentle ambient glow)
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(
                          alpha: isDark ? (0.18 + 0.14 * v) : (0.14 + 0.10 * v),
                        ),
                        blurRadius: 12.0 + 8.0 * v,
                        spreadRadius: 1.0 + 2.0 * v,
                      ),
                      // Outer soft radiant emerald glow
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(
                          alpha: isDark ? (0.10 + 0.10 * v) : (0.08 + 0.08 * v),
                        ),
                        blurRadius: 18.0 + 10.0 * v,
                        spreadRadius: 2.0 + 3.0 * v,
                      ),
                      // Ambient depth shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ScanFab(onPressed: widget.onScanPressed),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the bottom navigation bar:
/// - Fills both sides (edge-to-edge)
/// - Top-left & top-right corners curved only (radius: cornerRadius)
/// - Bottom corners straight
/// - Center smooth curved notch around the camera button
class _CurvedNavBarPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double notchRadius;
  final double notchCenterY;
  final double cornerRadius;

  _CurvedNavBarPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    this.notchRadius = 42.0,
    this.notchCenterY = 12.0,
    this.cornerRadius = 24.0,
  });

  Path _createPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = notchCenterY;
    final r = notchRadius;
    const s = 14.0; // shoulder transition width

    path.moveTo(0, cornerRadius);

    // Top-left curved corner only
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );

    // Left straight segment
    path.lineTo(cx - r - s, 0);

    // Smooth curved notch around camera button
    path.cubicTo(
      cx - r - s * 0.5, 0,
      cx - r, cy - r * 0.45,
      cx - r, cy,
    );
    path.arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      clockwise: false,
    );
    path.cubicTo(
      cx + r, cy - r * 0.45,
      cx + r + s * 0.5, 0,
      cx + r + s, 0,
    );

    // Right straight segment
    path.lineTo(w - cornerRadius, 0);

    // Top-right curved corner only
    path.arcToPoint(
      Offset(w, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Right edge down to bottom
    path.lineTo(w, h);
    // Straight bottom edge
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPath(size);

    // Soft ambient shadow along the top curved edge
    canvas.drawShadow(path, shadowColor, 10.0, false);

    // Fill background
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Stroke top contour line (including corners & curved notch)
    final borderPath = Path();
    final w = size.width;
    final cx = w / 2;
    final cy = notchCenterY;
    final r = notchRadius;
    const s = 14.0;

    borderPath.moveTo(0, cornerRadius);
    borderPath.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );
    borderPath.lineTo(cx - r - s, 0);
    borderPath.cubicTo(
      cx - r - s * 0.5, 0,
      cx - r, cy - r * 0.45,
      cx - r, cy,
    );
    borderPath.arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      clockwise: false,
    );
    borderPath.cubicTo(
      cx + r, cy - r * 0.45,
      cx + r + s * 0.5, 0,
      cx + r + s, 0,
    );
    borderPath.lineTo(w - cornerRadius, 0);
    borderPath.arcToPoint(
      Offset(w, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNavBarPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.notchCenterY != notchCenterY ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? const Color(0xFF4ADE80) : AppConstants.primaryGreen;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: activeColor.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with capsule highlight when active
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: isDark ? 0.18 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? activeColor : inactiveColor,
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -7,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.severitySevere,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.severitySevere.withValues(alpha: 0.40),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Text Label
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: isSelected ? 0.1 : 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Bottom sleek active micro-indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isSelected ? 14 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
