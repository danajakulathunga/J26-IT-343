import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bananaguard_ai/core/storage/storage_service.dart';

class AppConstants {
  static const String appName = 'BananaGuard AI';

  // Default Local API URLs
  static const String defaultLocalIpUrl = 'http://192.168.1.172:8000';
  static const String defaultTunnelUrl = 'http://localhost:8000';

  // Configurable API Base URL with smart auto-fallback
  static String get defaultApiBaseUrl {
    final custom = storageService.getCustomServerUrl();
    if (custom != null && custom.trim().isNotEmpty) {
      if (custom.contains('trycloudflare.com')) {
        return kIsWeb ? 'http://localhost:8000' : defaultLocalIpUrl;
      }
      return custom.trim();
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return kIsWeb ? 'http://localhost:8000' : defaultLocalIpUrl;
  }

  // Storage Keys
  static const String keyAccessToken = 'bg_access_token';
  static const String keyRefreshToken = 'bg_refresh_token';
  static const String keyUserData = 'bg_user_data';
  static const String keyGuestId = 'bg_guest_id';
  static const String keyGuestName = 'bg_guest_name';
  static const String keyIsFreeUsing = 'bg_is_free_using';
  static const String keyLanguage = 'bg_preferred_lang';
  static const String keyTheme = 'bg_theme_mode';
  static const String keyFirstLaunch = 'bg_is_first_launch';
  static const String keyCustomServerUrl = 'bg_custom_server_url';

  // Color Palette - Custom Banana-Inspired Material 3
  static const Color primaryGreen = Color(0xFF1B5E20);      // Deep leaf green
  static const Color primaryLightGreen = Color(0xFF2E7D32);
  static const Color accentYellow = Color(0xFFEAB308);       // Warm banana yellow
  static const Color accentYellowLight = Color(0xFFFEF08A);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F172A);

  // Severity Classification Colors
  static const Color severityMild = Color(0xFF16A34A);       // Green
  static const Color severityModerate = Color(0xFFD97706);   // Amber / Orange
  static const Color severitySevere = Color(0xFFDC2626);     // Red

  // Severity Weights for Index Gauge
  static const double weightMild = 20.0;
  static const double weightModerate = 50.0;
  static const double weightSevere = 85.0;
}
