import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/screens/splash_screen.dart';
import 'package:bananaguard_ai/screens/onboarding_language_screen.dart';
import 'package:bananaguard_ai/screens/auth_landing_screen.dart';
import 'package:bananaguard_ai/screens/sign_in_screen.dart';
import 'package:bananaguard_ai/screens/sign_up_screen.dart';
import 'package:bananaguard_ai/screens/forgot_password_screen.dart';
import 'package:bananaguard_ai/screens/reset_password_screen.dart';
import 'package:bananaguard_ai/screens/guest_name_screen.dart';
import 'package:bananaguard_ai/screens/home_screen.dart';
import 'package:bananaguard_ai/screens/scan_capture_screen.dart';
import 'package:bananaguard_ai/screens/analyzing_screen.dart';
import 'package:bananaguard_ai/screens/result_screen.dart';
import 'package:bananaguard_ai/screens/history_screen.dart';
import 'package:bananaguard_ai/screens/scan_detail_screen.dart';
import 'package:bananaguard_ai/screens/notifications_screen.dart';
import 'package:bananaguard_ai/screens/notification_settings_screen.dart';
import 'package:bananaguard_ai/screens/profile_screen.dart';
import 'package:bananaguard_ai/screens/settings_screen.dart';
import 'package:bananaguard_ai/widgets/bottom_nav_bar.dart';

CustomTransitionPage<T> _quickPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding-language',
      builder: (context, state) => const OnboardingLanguageScreen(),
    ),
    GoRoute(
      path: '/auth-landing',
      builder: (context, state) => const AuthLandingScreen(),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/sign-up',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        return ResetPasswordScreen(initialEmail: email);
      },
    ),
    GoRoute(
      path: '/guest-name',
      builder: (context, state) => const GuestNameScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: navigationShell.currentIndex,
            onTapIndex: (index) {
              if (index == 3) {
                context.push('/profile');
              } else {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              }
            },
            onScanPressed: () => context.push('/scan-capture'),
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              pageBuilder: (context, state) => const NoTransitionPage(child: HistoryScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              pageBuilder: (context, state) => const NoTransitionPage(child: NotificationsScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/scan-capture',
      pageBuilder: (context, state) => _quickPage(
        key: state.pageKey,
        child: const ScanCaptureScreen(),
      ),
    ),
    GoRoute(
      path: '/analyzing',
      pageBuilder: (context, state) => _quickPage(
        key: state.pageKey,
        child: const AnalyzingScreen(),
      ),
    ),
    GoRoute(
      path: '/result/:scanId',
      pageBuilder: (context, state) {
        final scanId = state.pathParameters['scanId'];
        return NoTransitionPage(
          key: state.pageKey,
          child: ResultScreen(scanId: scanId),
        );
      },
    ),
    GoRoute(
      path: '/result',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const ResultScreen(),
      ),
    ),
    GoRoute(
      path: '/scan-detail',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'] ?? '';
        return NoTransitionPage(
          key: state.pageKey,
          child: ScanDetailScreen(scanId: id),
        );
      },
    ),
    GoRoute(
      path: '/notification-settings',
      pageBuilder: (context, state) => _quickPage(
        key: state.pageKey,
        child: const NotificationSettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _quickPage(
        key: state.pageKey,
        child: const ProfileScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _quickPage(
        key: state.pageKey,
        child: const SettingsScreen(),
      ),
    ),
  ],
);
