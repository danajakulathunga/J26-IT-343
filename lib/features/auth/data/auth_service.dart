import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { farmer, exporter, admin }

class AuthUser {
  final String fullName;
  final String emailOrPhone;
  final String estateOrCompany;
  final UserRole role;

  const AuthUser({
    required this.fullName,
    required this.emailOrPhone,
    required this.estateOrCompany,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin || role == UserRole.exporter;
}

class AuthState {
  final bool isAuthenticated;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAdmin => user?.isAdmin ?? false;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _loadSession());
    return const AuthState();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('is_authenticated') ?? false;
      if (isAuth) {
        final name = prefs.getString('user_name') ?? 'Kumara Perera';
        final contact = prefs.getString('user_contact') ?? 'kumara@estate.lk';
        final estate = prefs.getString('user_estate') ?? 'Ruwan Estates';
        final roleStr = prefs.getString('user_role') ?? 'farmer';

        state = state.copyWith(
          isAuthenticated: true,
          user: AuthUser(
            fullName: name,
            emailOrPhone: contact,
            estateOrCompany: estate,
            role: roleStr == 'exporter' ? UserRole.exporter : UserRole.farmer,
          ),
        );
      }
    } catch (_) {}
  }

  Future<bool> login(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 700));

    if (emailOrPhone.trim().isEmpty || password.length < 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a valid email/phone and password.',
      );
      return false;
    }

    final user = AuthUser(
      fullName: 'Kumara Perera',
      emailOrPhone: emailOrPhone.trim(),
      estateOrCompany: 'Ruwan Estates',
      role: UserRole.farmer,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('user_name', user.fullName);
      await prefs.setString('user_contact', user.emailOrPhone);
      await prefs.setString('user_estate', user.estateOrCompany);
      await prefs.setString('user_role', 'farmer');
    } catch (_) {}

    state = state.copyWith(
      isAuthenticated: true,
      user: user,
      isLoading: false,
    );
    return true;
  }

  Future<bool> register({
    required String fullName,
    required String estateOrCompany,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 700));

    if (fullName.trim().isEmpty || phone.trim().isEmpty || password.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please fill in all required fields (min 6 char password).',
      );
      return false;
    }

    final user = AuthUser(
      fullName: fullName.trim(),
      emailOrPhone: phone.trim(),
      estateOrCompany: estateOrCompany.trim(),
      role: role,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('user_name', user.fullName);
      await prefs.setString('user_contact', user.emailOrPhone);
      await prefs.setString('user_estate', user.estateOrCompany);
      await prefs.setString('user_role', role.name);
    } catch (_) {}

    state = state.copyWith(
      isAuthenticated: true,
      user: user,
      isLoading: false,
    );
    return true;
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
