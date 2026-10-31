import 'package:flutter/material.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/utils/greeting.dart';

class WelcomeCard extends StatelessWidget {
  final String greeting;
  final String languageCode;
  final String? fullName;
  final VoidCallback? onScanPressed;
  final VoidCallback? onLibraryPressed;

  const WelcomeCard({
    super.key,
    required this.greeting,
    required this.languageCode,
    this.fullName,
    this.onScanPressed,
    this.onLibraryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final period = getGreetingPeriod(DateTime.now());

    // Period icon and badge styling
    IconData timeIcon;
    Color timeIconColor;
    Color timeBgColor;
    String timeLabel;

    switch (period) {
      case GreetingPeriod.morning:
        timeIcon = Icons.wb_sunny_rounded;
        timeIconColor = const Color(0xFFD97706);
        timeBgColor = const Color(0xFFFEF3C7);
        timeLabel = languageCode == 'si'
            ? 'උදෑසන පරීක්ෂාව'
            : (languageCode == 'ta' ? 'காலை ஆய்வு' : 'Morning Inspection');
        break;
      case GreetingPeriod.afternoon:
        timeIcon = Icons.wb_twilight_rounded;
        timeIconColor = const Color(0xFFEA580C);
        timeBgColor = const Color(0xFFFFEDD5);
        timeLabel = languageCode == 'si'
            ? 'දහවල් පරීක්ෂාව'
            : (languageCode == 'ta' ? 'மதிய ஆய்வு' : 'Midday Field Session');
        break;
      case GreetingPeriod.evening:
        timeIcon = Icons.wb_twighlight;
        timeIconColor = const Color(0xFFC026D3);
        timeBgColor = const Color(0xFFFAE8FF);
        timeLabel = languageCode == 'si'
            ? 'සන්ධ්‍යා පරීක්ෂාව'
            : (languageCode == 'ta' ? 'மாலை ஆய்வு' : 'Evening Inspection');
        break;
      case GreetingPeriod.night:
        timeIcon = Icons.nightlight_round;
        timeIconColor = const Color(0xFF4F46E5);
        timeBgColor = const Color(0xFFE0E7FF);
        timeLabel = languageCode == 'si'
            ? 'රාත්‍රී සමාලෝචනය'
            : (languageCode == 'ta' ? 'இரவு ஆய்வு' : 'Night Review');
        break;
    }

    String subtitleText;
    if (languageCode == 'si') {
      subtitleText =
          'කෙසෙල් වගාවේ රෝග සහ හානි කල්තියා හඳුනා ගැනීමට AI පද්ධතිය සූදානම්.';
    } else if (languageCode == 'ta') {
      subtitleText =
          'வாழை பயிர் நோய்கள் மற்றும் குறைபாடுகளை முன்கூட்டியே கண்டறிய AI தயார்.';
    } else {
      subtitleText =
          'AI-powered banana pathology diagnostics ready. Scan leaves or fruit to detect diseases and severity.';
    }

    final cardBg = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppConstants.primaryGreen.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Subtle decorative background leaf watermark/glow
            Positioned(
              right: -24,
              bottom: -24,
              child: Icon(
                Icons.eco_rounded,
                size: 140,
                color: AppConstants.primaryGreen.withValues(alpha: isDark ? 0.06 : 0.04),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badge row: Time of day chip + AI Status
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Time-of-day pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? timeIconColor.withValues(alpha: 0.2) : timeBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(timeIcon, size: 14, color: timeIconColor),
                            const SizedBox(width: 6),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : timeIconColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // System Status Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppConstants.primaryGreen.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppConstants.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'AI Ready',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.primaryGreen,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Greeting Headline
                  Text(
                    greeting,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Subtitle / Prompt
                  Text(
                    subtitleText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      height: 1.45,
                      fontSize: 13.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Feature highlight pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FeaturePill(
                        icon: Icons.check_circle_outline_rounded,
                        label: '17 Conditions',
                        isDark: isDark,
                      ),
                      _FeaturePill(
                        icon: Icons.grain_rounded,
                        label: 'Grad-CAM',
                        isDark: isDark,
                      ),
                      _FeaturePill(
                        icon: Icons.speed_rounded,
                        label: 'Severity 0-100',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppConstants.primaryGreen,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
