import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/user.dart';
import 'package:bananaguard_ai/services/auth_service.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.user, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => user != null;
  bool get isGuest => user?.isGuest ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    checkCurrentUser();
  }

  String _parseError(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        final targetUrl = apiClient.dio.options.baseUrl.isNotEmpty
            ? apiClient.dio.options.baseUrl
            : AppConstants.defaultApiBaseUrl;
        return 'Cannot connect to server ($targetUrl). Please check your Wi-Fi or PC Firewall.';
      }
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data['error'] is Map && data['error']['message_en'] != null) {
          return data['error']['message_en'].toString();
        }
        if (data['detail'] != null) {
          return data['detail'].toString();
        }
      }
    }
    return fallback;
  }

  Future<UserModel?> checkCurrentUser() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await authService.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await authService.login(email: email, password: password);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e, 'Invalid email or password'));
      return false;
    }
  }

  Future<bool> signUp(String fullName, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await authService.signUp(fullName: fullName, email: email, password: password);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e, 'Registration failed. Email may already exist.'));
      return false;
    }
  }

  Future<bool> loginAsGuest(String name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final guest = await authService.guestLogin(name);
      state = state.copyWith(user: guest, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to initialize guest session');
      return false;
    }
  }

  Future<void> updateProfile({String? fullName, String? preferredLanguage}) async {
    if (state.user == null || state.isGuest) return;
    try {
      final updated = await authService.updateProfile(
        fullName: fullName,
        preferredLanguage: preferredLanguage,
      );
      state = state.copyWith(user: updated);
    } catch (_) {}
  }

  Future<void> logout() async {
    await authService.logout();
    state = AuthState(user: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
