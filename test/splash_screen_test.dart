import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/screens/splash_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';

void main() {
  testWidgets('SplashScreen renders image, branding, and exact footer credit', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/onboarding-language', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/auth-landing', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Initial frame renders branding, image, and footer
    expect(find.text('BananaGuard AI'), findsOneWidget);
    expect(find.text('Intelligent Defect & Disease Diagnostics'), findsOneWidget);
    expect(find.text('© 2026 All rights reserved. Developed by DVK'), findsOneWidget);

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final Image imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final AssetImage assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, 'assets/images/SplashScreen_Image.png');

    // Advance time past the splash timer
    await tester.pump(const Duration(seconds: 3));
  });
}
