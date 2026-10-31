import 'package:dio/dio.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/models/user.dart';

class AuthService {
  Future<UserModel> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await apiClient.dio.post(
      '/auth/signup',
      data: {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final tokens = response.data['tokens'];
    await storageService.saveTokens(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );

    final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    await storageService.saveUser(user);
    await storageService.setFreeUsing(false);

    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.dio.post(
      '/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final tokens = response.data['tokens'];
    await storageService.saveTokens(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );

    final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    await storageService.saveUser(user);
    await storageService.setFreeUsing(false);

    return user;
  }

  Future<void> forgotPassword(String email) async {
    await apiClient.dio.post(
      '/auth/forgot-password',
      data: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await apiClient.dio.post(
      '/auth/reset-password',
      data: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'new_password': newPassword,
      },
    );
  }

  Future<UserModel> guestLogin(String name) async {
    await storageService.clearTokens();
    await storageService.clearUser();
    final guestId = storageService.getOrCreateGuestId();
    await storageService.setGuestName(name.trim());
    await storageService.setFreeUsing(true);
    final guest = UserModel.guest(guestId: guestId, name: name.trim());
    await storageService.saveUser(guest);
    return guest;
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await storageService.getAccessToken();
    final refreshToken = await storageService.getRefreshToken();
    final savedUser = await storageService.getSavedUser();

    // 1. Authenticated User Flow
    if ((token != null && token.isNotEmpty) || (refreshToken != null && refreshToken.isNotEmpty)) {
      try {
        final response = await apiClient.dio.get('/users/me');
        final user = UserModel.fromJson(response.data as Map<String, dynamic>);
        await storageService.saveUser(user);
        await storageService.setFreeUsing(false);
        return user;
      } on DioException catch (dioErr) {
        final status = dioErr.response?.statusCode;
        if (status == 401 || status == 403) {
          // Token expired or invalid; try refreshing with refresh token
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              final refreshRes = await Dio(
                BaseOptions(
                  baseUrl: AppConstants.defaultApiBaseUrl,
                  connectTimeout: const Duration(seconds: 10),
                ),
              ).post('/auth/refresh', data: {'refresh_token': refreshToken});

              if (refreshRes.statusCode == 200) {
                final newAccess = refreshRes.data['access_token'] as String;
                await storageService.saveTokens(
                  accessToken: newAccess,
                  refreshToken: refreshToken,
                );

                // Re-attempt fetching user profile with new access token
                final retryRes = await apiClient.dio.get(
                  '/users/me',
                  options: Options(headers: {'Authorization': 'Bearer $newAccess'}),
                );
                final refreshedUser = UserModel.fromJson(retryRes.data as Map<String, dynamic>);
                await storageService.saveUser(refreshedUser);
                await storageService.setFreeUsing(false);
                return refreshedUser;
              }
            } catch (_) {
              // Refresh also failed; session expired
              await storageService.clearAllSession();
              return null;
            }
          }

          // No valid refresh token available
          await storageService.clearAllSession();
          return null;
        }

        // If it's a network offline or connection error, return persisted cached user
        if (savedUser != null && !savedUser.isGuest) {
          return savedUser;
        }
      } catch (_) {
        if (savedUser != null && !savedUser.isGuest) {
          return savedUser;
        }
      }
    }

    // 2. Free Using (Guest) Flow
    if (storageService.isFreeUsing()) {
      final guestName = storageService.getGuestName();
      if (guestName != null && guestName.trim().isNotEmpty) {
        final guestId = storageService.getOrCreateGuestId();
        return UserModel.guest(guestId: guestId, name: guestName.trim());
      }
    }

    return null;
  }

  Future<UserModel> updateProfile({String? fullName, String? preferredLanguage}) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (preferredLanguage != null) data['preferred_language'] = preferredLanguage;

    final response = await apiClient.dio.patch('/users/me', data: data);
    final updated = UserModel.fromJson(response.data as Map<String, dynamic>);
    await storageService.saveUser(updated);
    return updated;
  }

  Future<void> logout() async {
    await storageService.clearAllSession();
  }
}

final authService = AuthService();
