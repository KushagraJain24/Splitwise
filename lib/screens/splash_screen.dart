import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/main.dart';
import 'package:splitwise/utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();

    // Periodically check if AuthProvider is initialized, and navigate
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      if (authProvider.isInitialized) {
        _navigateToNextScreen();
      } else {
        // Keep checking
        _listenToAuthInit();
      }
    });
  }

  void _listenToAuthInit() {
    // Add a post frame callback listener to context to listen to provider updates
    final authProvider = context.read<AuthProvider>();
    
    // We register a listener that triggers navigation when initialized
    void listener() {
      if (authProvider.isInitialized) {
        authProvider.removeListener(listener);
        if (mounted) {
          _navigateToNextScreen();
        }
      }
    }

    authProvider.addListener(listener);
  }

  void _navigateToNextScreen() {
    // Navigate with a custom smooth fade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppConstants.premiumGradient,
            ),
          ),
          
          // Glowing Ambient Circle behind logo
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value * 0.15,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.accentTeal.withOpacity(0.5),
                          blurRadius: 100,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Animated Logo & Branding Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: AppConstants.glassDecoration(
                            color: Colors.white,
                            opacity: 0.05,
                            borderRadius: 32.0,
                          ).copyWith(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(28.0),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Text with fade-in animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          'S P L I T W I S E',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6.0,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Split bills, settle debts, stay friends.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.textSecondary.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // Glowing customized loader spinner
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppConstants.accentTeal.withOpacity(0.8),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
