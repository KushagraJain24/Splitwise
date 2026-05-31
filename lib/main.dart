import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/screens/auth/login_screen.dart';
import 'package:splitwise/screens/dashboard/dashboard_screen.dart';
import 'package:splitwise/screens/splash_screen.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/firebase_options.dart';
import 'package:splitwise/services/auth_service.dart';
import 'package:splitwise/models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialized via DefaultFirebaseOptions successfully.");
    } else {
      // Fallback to default native configuration files (google-services.json / GoogleService-Info.plist)
      await Firebase.initializeApp();
      debugPrint("Firebase initialized via native config file successfully.");
    }
  } catch (e) {
    debugPrint("Firebase not initialized: running in Mock Local Mode. Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'Splitwise Clone MVP',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark, // Default to stunning dark mode
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppConstants.backgroundDark,
          primaryColor: AppConstants.accentTeal,
          cardColor: AppConstants.cardDark,
          colorScheme: ColorScheme.dark(
            background: AppConstants.backgroundDark,
            primary: AppConstants.accentTeal,
            secondary: AppConstants.accentIndigo,
            surface: AppConstants.cardDark,
            error: AppConstants.debitOrange,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
            bodyLarge: const TextStyle(color: AppConstants.textPrimary),
            bodyMedium: const TextStyle(color: AppConstants.textSecondary),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastLoadedUid;
  bool _bypassWarning = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // If Firebase is not enabled (mock mode) and warning not bypassed, show instructions
    if (!AuthService.isFirebaseEnabled() && !_bypassWarning) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppConstants.premiumGradient,
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: ClipRRect(
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 64,
                            color: AppConstants.debitOrange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Firebase Setup Required',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This app is currently running in Offline Mock Sandbox Mode because Firebase has not been initialized yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'How to connect your actual database:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.accentTeal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '1. Create a Firebase Project in the Firebase Console.',
                                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '2. Place google-services.json in android/app/ (for Android devices).',
                                  style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '3. Alternatively, update API keys in lib/firebase_options.dart.',
                                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _bypassWarning = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.accentTeal,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('PROCEED TO OFFLINE SANDBOX', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!authProvider.isInitialized) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppConstants.premiumGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
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
                    fontSize: 13,
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  color: AppConstants.accentTeal,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = authProvider.user;

    if (user == null) {
      _lastLoadedUid = null;
      return const LoginScreen();
    }

    if (user.phone == null || user.phone!.trim().isEmpty) {
      _lastLoadedUid = null;
      return PhoneSetupScreen(user: user);
    }

    // Trigger dashboard data load when user logs in or switches
    if (_lastLoadedUid != user.uid) {
      _lastLoadedUid = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppProvider>().loadDashboardData(user.uid);
      });
    }

    return const DashboardScreen();
  }
}

class PhoneSetupScreen extends StatefulWidget {
  final UserModel user;
  const PhoneSetupScreen({super.key, required this.user});

  @override
  State<PhoneSetupScreen> createState() => _PhoneSetupScreenState();
}

class _PhoneSetupScreenState extends State<PhoneSetupScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'COMPLETE PROFILE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your phone number to link your profile and retrieve group invitation history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 24),
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
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: AppConstants.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  labelStyle: const TextStyle(color: AppConstants.textSecondary),
                                  prefixIcon: const Icon(Icons.phone_outlined, color: AppConstants.textSecondary),
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
                                  if (value == null || value.trim().isEmpty) return 'Enter your phone number';
                                  final clean = value.replaceAll(RegExp(r'\D'), '');
                                  if (clean.length < 7) return 'Enter a valid phone number (min 7 digits)';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              authProvider.isLoading
                                  ? const Center(child: CircularProgressIndicator(color: AppConstants.accentTeal))
                                  : ElevatedButton(
                                      onPressed: () async {
                                        if (_formKey.currentState!.validate()) {
                                          await authProvider.updatePhone(_phoneController.text);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.accentTeal,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('SAVE AND LINK', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
