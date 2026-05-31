import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/screens/auth/signup_screen.dart';
import 'package:splitwise/utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.errorMessage != null) {
      authProvider.clearError();
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      await context.read<AuthProvider>().signIn(
            _emailController.text,
            _passwordController.text,
          );
    }
  }

  void _signInWithGoogle() async {
    await context.read<AuthProvider>().signInWithGoogle();
  }



  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo & Subtitle
                    Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'S P L I T W I S E',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Split bills, settle debts, stay friends.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glassmorphic Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          decoration: AppConstants.glassDecoration(
                            color: Colors.white,
                            opacity: 0.05,
                            borderRadius: 24.0,
                          ),
                          padding: const EdgeInsets.all(32.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: AppConstants.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    labelStyle: const TextStyle(color: AppConstants.textSecondary),
                                    prefixIcon: const Icon(Icons.email_outlined, color: AppConstants.textSecondary),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppConstants.accentTeal),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter your email';
                                    if (!value.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: AppConstants.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(color: AppConstants.textSecondary),
                                    prefixIcon: const Icon(Icons.lock_outlined, color: AppConstants.textSecondary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: AppConstants.textSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppConstants.accentTeal),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter your password';
                                    return null;
                                  },
                                ),
                                if (authProvider.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppConstants.debitOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppConstants.debitOrange.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppConstants.debitOrange, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            authProvider.errorMessage!,
                                            style: const TextStyle(color: AppConstants.debitOrange, fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Login Button
                                authProvider.isLoading
                                    ? const Center(child: CircularProgressIndicator(color: AppConstants.accentTeal))
                                    : ElevatedButton(
                                        onPressed: _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppConstants.accentTeal,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('LOG IN', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                 const SizedBox(height: 16),
                                 Row(
                                   children: [
                                     Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                                     Padding(
                                       padding: const EdgeInsets.symmetric(horizontal: 16),
                                       child: Text('OR', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.bold)),
                                     ),
                                     Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                                   ],
                                 ),
                                 const SizedBox(height: 16),
                                 OutlinedButton.icon(
                                   onPressed: _signInWithGoogle,
                                   icon: const Icon(Icons.login, color: AppConstants.accentTeal, size: 20),
                                   label: const Text('SIGN IN WITH GOOGLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                   style: OutlinedButton.styleFrom(
                                     side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                     padding: const EdgeInsets.symmetric(vertical: 16),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                   ),
                                 ),
                                 const SizedBox(height: 24),

                                // Go to Signup
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                    const Text("Don't have an account? ", style: TextStyle(color: AppConstants.textSecondary)),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                                        );
                                      },
                                      child: const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: AppConstants.accentTeal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
