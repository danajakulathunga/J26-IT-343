import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).languageCode;

    final subtitleText = lang == 'si'
        ? 'ස්වයංක්‍රීය කෙසෙල් දෝෂ සහ රෝග හඳුනාගැනීම, බරපතලකම තක්සේරු කිරීම සහ පැහැදිලි කළ හැකි AI තාක්ෂණය.'
        : (lang == 'ta'
            ? 'தானியங்கி வாழைப்பழ குறைபாடு கண்டறிதல், நோய் கண்டறிதல் மற்றும் தீவிர மதிப்பீடு.'
            : 'Automated banana defect detection, disease diagnosis, and severity estimation with explainable AI.');

    final signInText = lang == 'si' ? 'ඇතුල් වන්න' : (lang == 'ta' ? 'உள்நுழைய' : 'Sign In');
    final signUpText = lang == 'si' ? 'ලියාපදිංචි වන්න' : (lang == 'ta' ? 'கணக்கை உருவாக்கவும்' : 'Create an Account');
    final guestText = lang == 'si'
        ? 'නොමිලේ අමුත්තෙකු ලෙස ඉදිරියට යන්න'
        : (lang == 'ta' ? 'விருந்தினராக தொடரவும்' : 'Continue as Guest');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              // Banana Mascot / Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppConstants.accentYellow.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco_rounded,
                    size: 56,
                    color: AppConstants.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BananaGuard AI',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  subtitleText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // 1. Sign In Button
              ElevatedButton(
                onPressed: () => context.push('/sign-in'),
                child: Text(signInText),
              ),
              const SizedBox(height: 12),
              // 2. Sign Up Button (Outlined)
              OutlinedButton(
                onPressed: () => context.push('/sign-up'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppConstants.primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  signUpText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 3. Continue as Guest
              TextButton(
                onPressed: () => context.push('/guest-name'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 18, color: AppConstants.accentYellow),
                    const SizedBox(width: 6),
                    Text(
                      guestText,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryGreen,
                      ),
                    ),
                  ],
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
