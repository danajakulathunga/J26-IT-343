import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bananaguard_ai/core/router.dart';
import 'package:bananaguard_ai/core/theme/app_theme.dart';
import 'package:bananaguard_ai/providers/locale_provider.dart';
import 'package:bananaguard_ai/providers/theme_provider.dart';

import 'package:bananaguard_ai/l10n/app_localizations.dart';

class BananaGuardScrollBehavior extends MaterialScrollBehavior {
  const BananaGuardScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class BananaGuardApp extends ConsumerWidget {
  const BananaGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'BananaGuard AI',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      scrollBehavior: const BananaGuardScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: currentLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
