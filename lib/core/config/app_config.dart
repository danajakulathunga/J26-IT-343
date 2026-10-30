import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Toggle this to false when connecting to the real backend
  static const bool useMockApi = false;

  // Change this to the real backend URL when ready
  static const String baseUrl = 'http://localhost:8080/api';

  // API base URL for Identification module
  // Note: For physical devices on the same network, change this to http://<PC-LAN-IP>:8000
  static String get identificationBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
