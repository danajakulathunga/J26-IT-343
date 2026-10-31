import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/user.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: AppConstants.keyAccessToken, value: accessToken);
        await _secureStorage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
      }
    } catch (_) {}
    await _prefs?.setString(AppConstants.keyAccessToken, accessToken);
    await _prefs?.setString(AppConstants.keyRefreshToken, refreshToken);
  }

  Future<String?> getAccessToken() async {
    try {
      if (kIsWeb) return _prefs?.getString(AppConstants.keyAccessToken);
      final token = await _secureStorage.read(key: AppConstants.keyAccessToken);
      return token ?? _prefs?.getString(AppConstants.keyAccessToken);
    } catch (_) {
      return _prefs?.getString(AppConstants.keyAccessToken);
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      if (kIsWeb) return _prefs?.getString(AppConstants.keyRefreshToken);
      final token = await _secureStorage.read(key: AppConstants.keyRefreshToken);
      return token ?? _prefs?.getString(AppConstants.keyRefreshToken);
    } catch (_) {
      return _prefs?.getString(AppConstants.keyRefreshToken);
    }
  }

  Future<void> clearTokens() async {
    try {
      if (!kIsWeb) {
        await _secureStorage.delete(key: AppConstants.keyAccessToken);
        await _secureStorage.delete(key: AppConstants.keyRefreshToken);
      }
    } catch (_) {}
    await _prefs?.remove(AppConstants.keyAccessToken);
    await _prefs?.remove(AppConstants.keyRefreshToken);
  }

  // Cached User Profile persistence
  Future<void> saveUser(UserModel user) async {
    final jsonStr = jsonEncode(user.toJson());
    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: AppConstants.keyUserData, value: jsonStr);
      }
    } catch (_) {}
    await _prefs?.setString(AppConstants.keyUserData, jsonStr);
  }

  Future<UserModel?> getSavedUser() async {
    String? jsonStr;
    try {
      if (!kIsWeb) {
        jsonStr = await _secureStorage.read(key: AppConstants.keyUserData);
      }
    } catch (_) {}
    jsonStr ??= _prefs?.getString(AppConstants.keyUserData);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserModel.fromJson(map);
      } catch (_) {}
    }
    return null;
  }

  Future<void> clearUser() async {
    try {
      if (!kIsWeb) {
        await _secureStorage.delete(key: AppConstants.keyUserData);
      }
    } catch (_) {}
    await _prefs?.remove(AppConstants.keyUserData);
  }

  // Free Using (Guest) Management
  String getOrCreateGuestId() {
    String? guestId = _prefs?.getString(AppConstants.keyGuestId);
    if (guestId == null || guestId.isEmpty) {
      guestId = const Uuid().v4();
      _prefs?.setString(AppConstants.keyGuestId, guestId);
    }
    return guestId;
  }

  String? getGuestName() {
    return _prefs?.getString(AppConstants.keyGuestName);
  }

  Future<void> setGuestName(String name) async {
    await _prefs?.setString(AppConstants.keyGuestName, name);
  }

  bool isFreeUsing() {
    return _prefs?.getBool(AppConstants.keyIsFreeUsing) ?? false;
  }

  Future<void> setFreeUsing(bool active) async {
    await _prefs?.setBool(AppConstants.keyIsFreeUsing, active);
  }

  Future<void> clearGuest() async {
    await _prefs?.remove(AppConstants.keyGuestName);
    await _prefs?.remove(AppConstants.keyIsFreeUsing);
  }

  // Complete session wipe (Explicit Logout)
  Future<void> clearAllSession() async {
    await clearTokens();
    await clearUser();
    await clearGuest();
  }

  // Language & Theme
  String getLanguage() {
    return _prefs?.getString(AppConstants.keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String code) async {
    await _prefs?.setString(AppConstants.keyLanguage, code);
  }

  String getThemeMode() {
    return _prefs?.getString(AppConstants.keyTheme) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs?.setString(AppConstants.keyTheme, mode);
  }

  // First Launch Onboarding
  bool isFirstLaunch() {
    return _prefs?.getBool(AppConstants.keyFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    await _prefs?.setBool(AppConstants.keyFirstLaunch, false);
  }

  // Custom Server URL
  String? getCustomServerUrl() {
    return _prefs?.getString(AppConstants.keyCustomServerUrl);
  }

  Future<void> setCustomServerUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs?.remove(AppConstants.keyCustomServerUrl);
    } else {
      await _prefs?.setString(AppConstants.keyCustomServerUrl, url.trim());
    }
  }
}

final storageService = StorageService();
