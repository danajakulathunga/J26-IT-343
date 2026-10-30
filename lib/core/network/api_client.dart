import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static Dio get instance {
    // Add interceptors here if needed (e.g., for logging or auth)
    return _dio;
  }
}
