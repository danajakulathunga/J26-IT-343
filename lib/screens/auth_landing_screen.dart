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

          // 2. White color fadeout gradient overlay (matching modern landing design)
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

                            // Sleek brand mascot / eco badge
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppConstants.accentYellow.withOpacity(0.22),
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
                                  Icons.eco_rounded,
                                  size: 34,
                                  color: AppConstants.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Main Title
                            Text(
                              'BananaGuard AI',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
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
                                  fontSize: 14.5,
                                  height: 1.45,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 1. Sign In Button
                            ElevatedButton(
                              onPressed: () => context.push('/sign-in'),
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
                              child: Text(signInText),
                            ),
                            const SizedBox(height: 12),

                            // 2. Sign Up Button (Outlined)
                            OutlinedButton(
                              onPressed: () => context.push('/sign-up'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: AppConstants.primaryGreen,
                                minimumSize: const Size(double.infinity, 54),
                                side: const BorderSide(color: AppConstants.primaryGreen, width: 1.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                signUpText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppConstants.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3. Continue as Guest
                            TextButton(
                              onPressed: () => context.push('/guest-name'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flash_on_rounded,
                                    size: 18,
                                    color: AppConstants.accentYellow,
                                  ),
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
