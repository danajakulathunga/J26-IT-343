import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/models/condition_info.dart';
import 'package:bananaguard_ai/services/local_db.dart';

class ScanService {
  List<ConditionInfoModel>? _cachedConditions;
  List<VarietyModel>? _cachedVarieties;

  Future<ScanResultModel> predictScan({
    required XFile imageFile,
    Uint8List? imageBytes,
    String? varietyId,
    String language = 'en',
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final bytes = imageBytes ?? await imageFile.readAsBytes();
    final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'banana.jpg';
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final mimeSubtype = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType('image', mimeSubtype),
      ),
      if (varietyId != null && varietyId.isNotEmpty) 'variety': varietyId,
      'language': language,
    });

    final response = await apiClient.dio.post(
      '/predict',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );

    final rawData = response.data;
    final Map<String, dynamic> dataMap = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : jsonDecode(rawData.toString()) as Map<String, dynamic>;

    final scanResult = ScanResultModel.fromJson(dataMap);

    // Persist original image bytes to local disk cache immediately for offline & restart persistence
    try {
      await apiClient.cacheImageBytes('/scans/${scanResult.scanId}/original', bytes);
      if (scanResult.images.originalUrl.isNotEmpty && scanResult.images.originalUrl != '/scans/${scanResult.scanId}/original') {
        await apiClient.cacheImageBytes(scanResult.images.originalUrl, bytes);
      }
    } catch (e) {
      debugPrint('Image persistent cache warning: $e');
    }

    // Persist to local database cache
    try {
      await localDbService.saveScan(scanResult);
    } catch (e) {
      debugPrint('Local DB cache warning: $e');
    }

    return scanResult;
  }

  Future<Map<String, dynamic>> checkBanana({
    required XFile imageFile,
    Uint8List? imageBytes,
  }) async {
    final bytes = imageBytes ?? await imageFile.readAsBytes();
    final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'banana_check.jpg';
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final mimeSubtype = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType('image', mimeSubtype),
      ),
    });

    final response = await apiClient.dio.post(
      '/check-banana',
      data: formData,
    );

    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'is_banana': false};
  }

  Future<List<ScanResultModel>> getScanHistory({
    int page = 1,
    int limit = 20,
    String? conditionType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (conditionType != null && conditionType.isNotEmpty && conditionType != 'All') {
        queryParams['condition_type'] = conditionType;
      }

      final response = await apiClient.dio.get('/scans', queryParameters: queryParams);
      if (response.data is Map && response.data['items'] is List) {
        final items = (response.data['items'] as List)
            .map((item) => ScanResultModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

        // Update local cache for offline reliability
        for (final scan in items) {
          try {
            await localDbService.saveScan(scan);
          } catch (_) {}
        }
        return items;
      }

      return await localDbService.getCachedScans();
    } catch (e) {
      debugPrint('getScanHistory API fetch warning: $e');
      // Offline fallback: load cached scans from SQLite or memory
      return await localDbService.getCachedScans();
    }
  }

  Future<ScanResultModel> getScanById(String scanId) async {
    try {
      final response = await apiClient.dio.get('/scans/$scanId');
      return ScanResultModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      // Check local cache
      final cached = await localDbService.getCachedScans();
      final match = cached.where((s) => s.scanId == scanId).firstOrNull;
      if (match != null) return match;
      rethrow;
    }
  }

  Future<void> deleteScan(String scanId) async {
    try {
      await apiClient.dio.delete('/scans/$scanId');
    } catch (_) {}
    await localDbService.deleteCachedScan(scanId);
  }

  Future<List<ConditionInfoModel>> getConditionsLibrary() async {
    if (_cachedConditions != null && _cachedConditions!.isNotEmpty) {
      return _cachedConditions!;
    }
    try {
      final response = await apiClient.dio.get('/meta/conditions');
      final list = (response.data as List<dynamic>)
          .map((e) => ConditionInfoModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        _cachedConditions = list;
        return list;
      }
    } catch (e) {
      debugPrint('getConditionsLibrary API error, using default conditions: $e');
    }
    return ConditionInfoModel.defaultConditions;
  }

  Future<List<VarietyModel>> getVarieties() async {
    if (_cachedVarieties != null) return _cachedVarieties!;
    try {
      final response = await apiClient.dio.get('/meta/varieties');
      final list = (response.data as List<dynamic>)
          .map((e) => VarietyModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        _cachedVarieties = list;
        return list;
      }
    } catch (_) {}
    return VarietyModel.defaultVarieties;
  }
}

final scanService = ScanService();
