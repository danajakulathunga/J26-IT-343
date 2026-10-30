import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_service.dart';
import '../widgets/custom_auth_field.dart';
import '../widgets/role_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _estateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '+94 ');
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  UserRole _selectedRole = UserRole.farmer;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _estateController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          fullName: _fullNameController.text,
          estateOrCompany: _estateController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _selectedRole,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Welcome to Field Kit.'),
            backgroundColor: Color(0xFF266E4E),
          ),
        );
        context.go('/');
      } else {
        final err = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Registration failed.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          ),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2A21),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  "Tell us who's inspecting the harvest.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),

                // I AM A Label
                const Text(
                  'I AM A',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF2E4638),
                  ),
                ),
                const SizedBox(height: 10),

                // Role Selector Cards
                Row(
                  children: [
                    RoleCard(
                      role: UserRole.farmer,
                      isSelected: _selectedRole == UserRole.farmer,
                      onTap: () => setState(() => _selectedRole = UserRole.farmer),
                    ),
                    const SizedBox(width: 14),
                    RoleCard(
                      role: UserRole.exporter,
                      isSelected: _selectedRole == UserRole.exporter,
                      onTap: () => setState(() => _selectedRole = UserRole.exporter),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Full Name
                CustomAuthField(
                  label: 'Full Name',
                  hintText: 'As on your export licence',
                  controller: _fullNameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Estate / Company
                CustomAuthField(
                  label: 'Estate / Company',
                  hintText: 'e.g. Ruwan Estates',
                  controller: _estateController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Estate or company name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                CustomAuthField(
                  label: 'Phone Number',
                  hintText: '+94',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().length < 8) {
                      return 'Valid phone number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                CustomAuthField(
                  label: 'Password',
                  hintText: 'Minimum 8 characters',
                  controller: _passwordController,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF266E4E),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Terms disclaimer
                Center(
                  child: Text(
                    'By continuing you agree to the Field Kit inspection terms.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Already have account?
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: Color(0xFF266E4E),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
