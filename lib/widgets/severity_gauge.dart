import 'package:flutter/material.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/widgets/creative_progress_bar.dart';

class SeverityGauge extends StatelessWidget {
  final double severityIndex; // 0.0 to 100.0
  final String? severityLevel;
  final double? severityConfidence; // 0.0 to 1.0 (optional)

  const SeverityGauge({
    super.key,
    required this.severityIndex,
    this.severityLevel,
    this.severityConfidence,
  });

  Color _getColorForIndex(double val) {
    if (val <= 35.0) return AppConstants.severityMild;
    if (val <= 50.0) {
      return Color.lerp(
        AppConstants.severityMild,
        AppConstants.severityModerate,
        (val - 35.0) / 15.0,
      )!;
    }
    if (val <= 70.0) return AppConstants.severityModerate;
    if (val <= 85.0) {
      return Color.lerp(
        AppConstants.severityModerate,
        AppConstants.severitySevere,
        (val - 70.0) / 15.0,
      )!;
    }
    return AppConstants.severitySevere;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    String title = 'Severity Index';
    String sub = '0–100 Scale';
    if (lang == 'si') {
      title = 'බරපතලකම් දර්ශකය';
      sub = 'ප්‍රමාණය 0–100';
    } else if (lang == 'ta') {
      title = 'தீவிர குறியீடு';
      sub = 'அளவு 0–100';
    }

    final targetIndex = severityIndex.clamp(0.0, 100.0);

    return TweenAnimationBuilder<double>(
      key: ValueKey(targetIndex),
      tween: Tween<double>(begin: 0.0, end: targetIndex),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final gaugeColor = _getColorForIndex(value);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      sub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gaugeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gaugeColor, width: 1.2),
                  ),
                  child: Text(
                    severityConfidence != null
                        ? '${value.toStringAsFixed(1)} / 100 (${(severityConfidence! * 100).toStringAsFixed(1)}%)'
                        : '${value.toStringAsFixed(1)} / 100',
                    style: TextStyle(
                      color: gaugeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Creative Gauge Progress Bar with Silky Smooth Left-to-Right Animated Fill
            CreativeProgressBar(
              progress: value / 100.0,
              color: gaugeColor,
              height: 12,
              backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.45),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 (Mild)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('50 (Moderate)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('100 (Severe)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        );
      },
    );
  }
}
