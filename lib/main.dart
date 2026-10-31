import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/app.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/services/notification_service.dart';
import 'package:bananaguard_ai/services/scan_service.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter and platform error handling for debug visibility
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [FlutterError]: ${details.exceptionAsString()}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🚨 [PlatformError]: $error\n$stack');
    return true;
  };

  // 1. Parallel startup bootstrap for minimum app launch latency
  await Future.wait([
    storageService.init(),
    notificationService.init(),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);

  // 2. Configure active API base URL in ApiClient with transparent auto-discovery
  final activeBaseUrl = AppConstants.defaultApiBaseUrl;
  apiClient.updateBaseUrl(activeBaseUrl);
  await apiClient.autoDetectAndConnect();
  debugPrint('🍌 [BananaGuard AI] Active API Base URL: ${apiClient.dio.options.baseUrl}');

  // 3. Fire non-blocking background metadata pre-warm for zero-latency screen opens
  Future.microtask(() async {
    try {
      await Future.wait([
        scanService.getConditionsLibrary(),
        scanService.getVarieties(),
      ]);
    } catch (_) {}
  });

  runApp(
    const ProviderScope(
      child: BananaGuardApp(),
    ),
  );
}
