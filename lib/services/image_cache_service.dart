import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent local disk cache for scanned fruit images (original & Grad-CAM).
/// Ensures images display immediately on smartphones even after app close/restarts
/// or when working offline / without active tunnel connection.
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  String? _cacheDirPath;

  Future<String?> _getCacheDirectoryPath() async {
    if (kIsWeb) return null;
    if (_cacheDirPath != null) return _cacheDirPath!;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/banana_scan_images');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _cacheDirPath = cacheDir.path;
      return _cacheDirPath;
    } catch (e) {
      debugPrint('Failed to resolve image cache directory: $e');
      return null;
    }
  }

  /// Converts any relative path or full URL into a safe, consistent local filename.
  /// E.g. '/scans/abc-123/original' -> 'scan_abc-123_original.jpg'
  /// E.g. 'https://host/scans/abc-123/gradcam' -> 'scan_abc-123_gradcam.jpg'
  String _toFileName(String pathOrUrl) {
    String clean = pathOrUrl;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        clean = Uri.parse(clean).path;
      } catch (_) {}
    }

    // Match standard scan image pattern /scans/{id}/{type}
    final scanMatch = RegExp(r'/scans/([a-zA-Z0-9_-]+)/(original|gradcam)').firstMatch(clean);
    if (scanMatch != null) {
      final scanId = scanMatch.group(1);
      final type = scanMatch.group(2);
      return 'scan_${scanId}_$type.jpg';
    }

    // Fallback: sanitized name
    final sanitized = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return sanitized.endsWith('.jpg') || sanitized.endsWith('.png')
        ? sanitized
        : '$sanitized.jpg';
  }

  /// Saves image bytes to local device persistent storage.
  Future<void> saveImage(String pathOrUrl, Uint8List bytes) async {
    if (kIsWeb || bytes.isEmpty) return;
    try {
      final dirPath = await _getCacheDirectoryPath();
      if (dirPath == null) return;

      final filename = _toFileName(pathOrUrl);
      final file = File('$dirPath/$filename');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('💾 [ImageCache] Persisted image to disk: $filename (${bytes.lengthInBytes} bytes)');
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Save image error: $e');
    }
  }

  /// Retrieves cached image bytes from local device storage if available.
  Future<Uint8List?> getImage(String pathOrUrl) async {
    if (kIsWeb) return null;
    try {
      final dirPath = await _getCacheDirectoryPath();
      if (dirPath == null) return null;

      final filename = _toFileName(pathOrUrl);
      final file = File('$dirPath/$filename');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          debugPrint('⚡ [ImageCache] Loaded from disk cache: $filename');
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Read image error: $e');
    }
    return null;
  }

  /// Check if an image is already cached on local device storage.
  Future<bool> hasImage(String pathOrUrl) async {
    if (kIsWeb) return false;
    try {
      final dirPath = await _getCacheDirectoryPath();
      if (dirPath == null) return false;

      final filename = _toFileName(pathOrUrl);
      final file = File('$dirPath/$filename');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }
}

final imageCacheService = ImageCacheService();
