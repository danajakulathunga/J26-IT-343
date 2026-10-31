import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/services/image_cache_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final Map<String, Uint8List> _imageCache = {};

  static const List<String> candidateUrls = [
    'http://localhost:8000',
    'http://127.0.0.1:8000',
    'http://192.168.1.172:8000',
    'http://192.168.8.233:8000',
    'http://localhost:8001',
    'http://127.0.0.1:8001',
    'http://192.168.1.172:8001',
    'http://192.168.8.233:8001',
    'http://172.28.9.58:8000',
    'http://10.0.2.2:8000',
  ];

  bool _isAutoDetecting = false;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.defaultApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await storageService.getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          } else {
            // Guest mode headers
            final guestId = storageService.getOrCreateGuestId();
            final guestName = storageService.getGuestName();
            options.headers['X-Guest-Id'] = guestId;
            if (guestName != null && guestName.isNotEmpty) {
              options.headers['X-Guest-Name'] = guestName;
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If 401 Unauthorized, attempt refresh token
          if (error.response?.statusCode == 401) {
            final refreshToken = await storageService.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final refreshResponse = await Dio(
                  BaseOptions(baseUrl: dio.options.baseUrl),
                ).post('/auth/refresh', data: {'refresh_token': refreshToken});

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['access_token'] as String;
                  await storageService.saveTokens(
                    accessToken: newAccessToken,
                    refreshToken: refreshToken,
                  );

                  // Retry original request with new token
                  final originalRequest = error.requestOptions;
                  originalRequest.headers['Authorization'] = 'Bearer $newAccessToken';

                  final retryResponse = await dio.fetch(originalRequest);
                  return handler.resolve(retryResponse);
                }
              } catch (_) {
                // Refresh failed; clear all persisted session data
                await storageService.clearAllSession();
              }
            }
          }

          // Automatic transparent fallback for connection failure or unreachable host
          final isConnectionErr = error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.unknown;

          if (isConnectionErr && !_isAutoDetecting) {
            final activeUrl = await autoDetectAndConnect(force: true);
            if (activeUrl != null && activeUrl != error.requestOptions.baseUrl) {
              try {
                final originalRequest = error.requestOptions;
                originalRequest.baseUrl = activeUrl;
                final retryResponse = await dio.fetch(originalRequest);
                return handler.resolve(retryResponse);
              } catch (_) {}
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Automatically discovers an active backend server without requiring manual dialog selection.
  Future<String?> autoDetectAndConnect({bool force = false}) async {
    if (_isAutoDetecting) return null;
    _isAutoDetecting = true;
    try {
      final current = dio.options.baseUrl;
      if (!force && current.isNotEmpty) {
        if (await _probeUrl(current)) {
          return current;
        }
      }

      final activeCustom = storageService.getCustomServerUrl();
      final ordered = <String>[
        if (kIsWeb) 'http://localhost:8000',
        if (kIsWeb) 'http://127.0.0.1:8000',
        if (activeCustom != null && activeCustom.isNotEmpty) activeCustom,
        'http://192.168.1.172:8000',
        'http://192.168.8.233:8000',
        if (kIsWeb) 'http://localhost:8001',
        ...candidateUrls,
      ];

      final seen = <String>{};
      final uniqueCandidates = ordered.where((u) => seen.add(u.toLowerCase())).toList();

      for (final candidate in uniqueCandidates) {
        if (await _probeUrl(candidate)) {
          updateBaseUrl(candidate);
          await storageService.setCustomServerUrl(candidate);
          debugPrint('🍌 [BananaGuard AI] Auto-connected to active backend: $candidate');
          return candidate;
        }
      }
      return null;
    } finally {
      _isAutoDetecting = false;
    }
  }

  Future<bool> _probeUrl(String url) async {
    try {
      var clean = url.trim();
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      final probeDio = Dio(
        BaseOptions(
          baseUrl: clean,
          connectTimeout: const Duration(milliseconds: 1500),
          receiveTimeout: const Duration(milliseconds: 1500),
        ),
      );
      final res = await probeDio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Downloads image bytes through authenticated Dio client with memory and persistent disk cache.
  /// Eliminates web canvas taint, network image auth failures, and ensures images survive app restarts.
  Future<Uint8List> fetchImageBytes(String pathOrUrl) async {
    String cleanPath = pathOrUrl.trim();
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      try {
        final parsed = Uri.parse(cleanPath);
        cleanPath = parsed.path;
      } catch (_) {
        cleanPath = cleanPath.replaceFirst(dio.options.baseUrl, '');
      }
    }

    // 1. In-memory cache check (fastest)
    if (_imageCache.containsKey(cleanPath)) {
      return _imageCache[cleanPath]!;
    }

    // 2. Persistent disk cache check (survives app close / restart and offline)
    final cachedDiskBytes = await imageCacheService.getImage(cleanPath);
    if (cachedDiskBytes != null && cachedDiskBytes.isNotEmpty) {
      _imageCache[cleanPath] = cachedDiskBytes;
      return cachedDiskBytes;
    }

    // 3. Network fetch via Dio
    final response = await dio.get<List<int>>(
      cleanPath,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.data == null || response.data!.isEmpty) {
      throw Exception('Empty image data received from server');
    }

    final bytes = Uint8List.fromList(response.data!);
    _imageCache[cleanPath] = bytes;

    // Persist to disk for future app restarts and offline use
    await imageCacheService.saveImage(cleanPath, bytes);

    return bytes;
  }

  /// Store known image bytes into both memory and persistent disk caches
  Future<void> cacheImageBytes(String pathOrUrl, Uint8List bytes) async {
    String cleanPath = pathOrUrl.trim();
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      try {
        cleanPath = Uri.parse(cleanPath).path;
      } catch (_) {}
    }
    _imageCache[cleanPath] = bytes;
    await imageCacheService.saveImage(cleanPath, bytes);
  }

  void updateBaseUrl(String newUrl) {
    var clean = newUrl.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isNotEmpty) {
      dio.options.baseUrl = clean;
    }
  }
}

final apiClient = ApiClient();
