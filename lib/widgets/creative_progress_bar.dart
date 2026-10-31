import 'package:flutter/material.dart';
import 'package:bananaguard_ai/core/constants.dart';

/// Pure hardware-accelerated progress bar with rich aesthetics:
/// - Smooth left-to-right fill animation with zero lag.
/// - Vibrant multi-tone gradient.
/// - 3D curved top gloss highlight.
/// - Glowing white spark bead at the leading right edge.
/// - Ambient colored glow shadow.
class CreativeProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double height;
  final Color? backgroundColor;

  const CreativeProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 10.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.45);
    final clamped = progress.clamp(0.0, 1.0);
    final r = BorderRadius.circular(height / 2);

    final lightColor = Color.lerp(color, Colors.white, 0.28)!;
    final darkColor = Color.lerp(color, Colors.black, 0.15)!;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            if (clamped > 0.005)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    gradient: LinearGradient(
                      colors: [lightColor, color, darkColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Top 3D curved glass reflection highlight
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: height * 0.42,
                          decoration: BoxDecoration(
                            borderRadius: r,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.35),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Leading edge glowing spark bead
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: height * 0.8,
                          height: height * 0.8,
                          margin: EdgeInsets.only(right: (height * 0.1).clamp(1.0, 3.0)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.95),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated Animated Condition Confidence row & progress bar.
/// Uses TweenAnimationBuilder for 100% zero-latency, 60fps butter-smooth animation.
class AnimatedConfidenceSection extends StatelessWidget {
  final double confidence; // e.g. 0.773 (0.0 to 1.0)
  final Color? color;
  final String title;
  final double height;

  const AnimatedConfidenceSection({
    super.key,
    required this.confidence,
    this.color,
    this.title = 'Condition Confidence:',
    this.height = 10.0,
  });

  Color _getConfidenceColor(double val) {
    if (val < 0.50) return AppConstants.severitySevere;
    if (val < 0.75) return AppConstants.severityModerate;
    return AppConstants.severityMild;
  }

  Widget _buildIndicatorDot({
    required String label,
    required Color dotColor,
    required TextStyle? textStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = confidence.clamp(0.0, 1.0);
    final barColor = color ?? _getConfidenceColor(target);

    final lang = Localizations.localeOf(context).languageCode;
    String lowText = 'Low';
    String modText = 'Moderate';
    String highText = 'High';
    if (lang == 'si') {
      lowText = 'අඩු';
      modText = 'මධ්‍යම';
      highText = 'ඉහළ';
    } else if (lang == 'ta') {
      lowText = 'குறைவு';
      modText = 'மிதமானது';
      highText = 'அதிகம்';
    }

    final legendTextStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey(target),
      tween: Tween<double>(begin: 0.0, end: target),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${(value * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            CreativeProgressBar(
              progress: value,
              color: barColor,
              height: height,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIndicatorDot(
                  label: '<50% $lowText',
                  dotColor: AppConstants.severitySevere,
                  textStyle: legendTextStyle,
                ),
                _buildIndicatorDot(
                  label: '50–75% $modText',
                  dotColor: AppConstants.severityModerate,
                  textStyle: legendTextStyle,
                ),
                _buildIndicatorDot(
                  label: '75%+ $highText',
                  dotColor: AppConstants.severityMild,
                  textStyle: legendTextStyle,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
