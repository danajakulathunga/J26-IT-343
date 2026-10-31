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
      'sub': 'ශ්‍රී ලාංකික ගොවි ප්‍රජාව සඳහා',
    },
    {
      'code': 'en',
      'native': 'English',
      'english': 'English',
      'sub': 'International & Academic Research',
    },
    {
      'code': 'ta',
      'native': 'தமிழ்',
      'english': 'Tamil',
      'sub': 'இலங்கை விவசாயிகளுக்காக',
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppConstants.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: AppConstants.primaryGreen,
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedLang == 'si'
                    ? 'ඔබගේ භාෂාව තෝරන්න'
                    : (_selectedLang == 'ta'
                        ? 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்'
                        : 'Choose Your Language'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedLang == 'si'
                    ? 'කෙසෙල් රෝග සහ දෝෂ හඳුනාගැනීම සඳහා භාෂාව සකසන්න'
                    : (_selectedLang == 'ta'
                        ? 'வாழைப்பழ குறைபாடு மற்றும் நோய் கண்டறிதலுக்கு மொழியை அமைக்கவும்'
                        : 'Select your preferred language for diagnostics'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = _languages[index];
                    final isSelected = _selectedLang == item['code'];

                    return InkWell(
                      onTap: () => _onSelect(item['code']!),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppConstants.primaryGreen.withOpacity(0.08)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppConstants.primaryGreen
                                : theme.colorScheme.outlineVariant.withOpacity(0.5),
                            width: isSelected ? 2 : 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: item['code']!,
                              groupValue: _selectedLang,
                              activeColor: AppConstants.primaryGreen,
                              onChanged: (val) {
                                if (val != null) _onSelect(val);
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['native']!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? AppConstants.primaryGreen
                                          : theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['sub']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _onContinue,
                child: Text(
                  _selectedLang == 'si'
                      ? 'ඉදිරියට යන්න'
                      : (_selectedLang == 'ta' ? 'தொடரவும்' : 'Continue'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
