import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';

class OnboardingLanguageScreen extends ConsumerStatefulWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  ConsumerState<OnboardingLanguageScreen> createState() =>
      _OnboardingLanguageScreenState();
}

class _OnboardingLanguageScreenState
    extends ConsumerState<OnboardingLanguageScreen> {
  String _selectedLang = 'en';

  final List<Map<String, String>> _languages = [
    {
      'code': 'si',
      'native': 'සිංහල',
      'english': 'Sinhala',
    },
    {
      'code': 'en',
      'native': 'English',
      'english': 'English',
    },
    {
      'code': 'ta',
      'native': 'தமிழ்',
      'english': 'Tamil',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLang = ref.read(localeProvider).languageCode;
  }

  void _onSelect(String code) {
    setState(() => _selectedLang = code);
    ref.read(localeProvider.notifier).setLocale(code);
  }

  Future<void> _onContinue() async {
    await storageService.setFirstLaunchCompleted();
    if (mounted) {
      context.go('/auth-landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleText = _selectedLang == 'si'
        ? 'ඔබගේ භාෂාව තෝරන්න'
        : (_selectedLang == 'ta'
            ? 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்'
            : 'Choose Your Language');

    final subtitleText = _selectedLang == 'si'
        ? 'කෙසෙල් රෝග සහ දෝෂ හඳුනාගැනීම සඳහා භාෂාව සකසන්න'
        : (_selectedLang == 'ta'
            ? 'வாழைப்பழ குறைபாடு மற்றும் நோய் கண்டறிதலுக்கு மொழியை அமைக்கவும்'
            : 'Select your preferred language for diagnostics');

    final continueText = _selectedLang == 'si'
        ? 'ඉදිරියට යන්න'
        : (_selectedLang == 'ta' ? 'තொடரவும்' : 'Continue');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full-screen background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // 2. White color fadeout gradient overlay (matching auth landing screen)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.30, 0.48, 0.68, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withOpacity(0.40),
                    Colors.white.withOpacity(0.92),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),

          // 3. Foreground content pushed to bottom over the white fadeout section
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            const Spacer(),

                            // Sleek language icon badge
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppConstants.primaryGreen.withOpacity(0.12),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.translate_rounded,
                                  size: 30,
                                  color: AppConstants.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Main Title
                            Text(
                              titleText,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: const Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Subtitle description
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                subtitleText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Compact 3-Language selection buttons (Row)
                            Row(
                              children: _languages.map((item) {
                                final isSelected = _selectedLang == item['code'];
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _onSelect(item['code']!),
                                        borderRadius: BorderRadius.circular(16),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppConstants.primaryGreen.withOpacity(0.08)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppConstants.primaryGreen
                                                  : const Color(0xFFCBD5E1),
                                              width: isSelected ? 2 : 1.2,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: AppConstants.primaryGreen.withOpacity(0.16),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.03),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (isSelected) ...[
                                                    const Icon(
                                                      Icons.check_circle_rounded,
                                                      size: 15,
                                                      color: AppConstants.primaryGreen,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Flexible(
                                                    child: Text(
                                                      item['native']!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected
                                                            ? AppConstants.primaryGreen
                                                            : const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                item['english']!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  color: isSelected
                                                      ? AppConstants.primaryGreen.withOpacity(0.85)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // Continue Button
                            ElevatedButton(
                              onPressed: _onContinue,
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
                              child: Text(continueText),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
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
