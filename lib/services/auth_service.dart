import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/services/db_service.dart';

class AuthService {
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  // Stream controller for mock auth state changes
  final StreamController<UserModel?> _mockAuthController = StreamController<UserModel?>.broadcast();

  // In-Memory storage for mock users
  static final List<UserModel> mockUsersList = [
    UserModel(
      uid: 'alice_uid',
      email: 'alice@example.com',
      displayName: 'Alice Smith',
      phone: '9111111111',
      isPlaceholder: false,
      createdAt: DateTime.now(),
    ),
    UserModel(
      uid: 'bob_uid',
      email: 'bob@example.com',
      displayName: 'Bob Jones',
      phone: '9222222222',
      isPlaceholder: false,
      createdAt: DateTime.now(),
    ),
    UserModel(
      uid: 'charlie_uid',
      email: 'charlie@example.com',
      displayName: 'Charlie Brown',
      phone: '9333333333',
      isPlaceholder: false,
      createdAt: DateTime.now(),
    ),
  ];

  // In-Memory mock credentials map (email -> password)
  static final Map<String, String> mockCredentials = {
    'alice@example.com': 'password123',
    'bob@example.com': 'password123',
    'charlie@example.com': 'password123',
  };

  UserModel? _currentMockUser;

  AuthService() {
    // If we are in mock mode, seed the DbService with our mock users
    if (!isFirebaseEnabled()) {
      for (var u in mockUsersList) {
        DbService.addMockUser(u);
      }
    }
  }

  /// Helper to check if Firebase is initialized and enabled
  static bool isFirebaseEnabled() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Stream of user auth state changes
  Stream<UserModel?> get onAuthStateChanged {
    if (isFirebaseEnabled()) {
      return _firebaseAuth.authStateChanges().asyncMap((User? firebaseUser) async {
        if (firebaseUser == null) return null;
        try {
          // Fetch full profile details from database service
          final profile = await DbService().getUserProfile(firebaseUser.uid);
          if (profile == null) {
            return UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
              isPlaceholder: false,
              createdAt: DateTime.now(),
            );
          }
          return profile;
        } catch (e) {
          // In case of network errors/offline, return a fallback UserModel with Firebase basic info
          return UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
            isPlaceholder: false,
            createdAt: DateTime.now(),
          );
        }
      });
    } else {
      return _mockAuthController.stream;
    }
  }

  /// Get current user synchronously/asynchronously
  Future<UserModel?> getCurrentUser() async {
    if (isFirebaseEnabled()) {
      final User? firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return null;
      return await DbService().getUserProfile(firebaseUser.uid);
    } else {
      return _currentMockUser;
    }
  }

  /// Sign In
  Future<UserModel> signIn(String email, String password) async {
    final sanitizedEmail = email.trim().toLowerCase();

    if (isFirebaseEnabled()) {
      final UserCredential creds = await _firebaseAuth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );
      if (creds.user == null) throw Exception("Authentication failed");
      final profile = await DbService().getUserProfile(creds.user!.uid);
      if (profile == null) throw Exception("User profile not found");
      return profile;
    } else {
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate network latency

      if (!mockCredentials.containsKey(sanitizedEmail) || mockCredentials[sanitizedEmail] != password) {
        throw Exception("Invalid email or password");
      }

      // Find user
      final user = DbService.getMockUserByEmail(sanitizedEmail);
      if (user == null) {
        throw Exception("User profile not found in mock database");
      }

      _currentMockUser = user;
      _mockAuthController.add(user);
      return user;
    }
  }

  /// Sign Up / Register
  Future<UserModel> signUp(String email, String password, String displayName, String phone) async {
    final sanitizedEmail = email.trim().toLowerCase();
    final sanitizedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');

    if (isFirebaseEnabled()) {
      // 1. Create in Firebase Auth
      final UserCredential creds = await _firebaseAuth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );
      if (creds.user == null) throw Exception("Failed to create user credential");

      // 2. Write to users collection
      final UserModel newUser = UserModel(
        uid: creds.user!.uid,
        email: sanitizedEmail,
        displayName: displayName.trim(),
        phone: sanitizedPhone.isNotEmpty ? sanitizedPhone : null,
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );

      await DbService().createUserProfile(newUser);

      // Check and claim placeholder history if it exists (by email or phone)
      var existingPlaceholder = await DbService().searchUserByEmail(sanitizedEmail);
      if (existingPlaceholder == null && sanitizedPhone.isNotEmpty) {
        existingPlaceholder = await DbService().searchUserByPhone(sanitizedPhone);
      }
      if (existingPlaceholder != null && existingPlaceholder.isPlaceholder) {
        await DbService().claimPlaceholderHistory(existingPlaceholder.uid, creds.user!.uid);
      }
      return newUser;
    } else {
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if user exists and is NOT a placeholder
      final existingUser = DbService.getMockUserByEmail(sanitizedEmail);
      if (existingUser != null && !existingUser.isPlaceholder) {
        throw Exception("Email address is already in use");
      }

      final String uid = existingUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      final UserModel newUser = UserModel(
        uid: uid,
        email: sanitizedEmail,
        displayName: displayName.trim(),
        phone: sanitizedPhone.isNotEmpty ? sanitizedPhone : null,
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );

      // Register mock user and credentials
      DbService.addMockUser(newUser);
      mockCredentials[sanitizedEmail] = password;

      // Check mock placeholders by phone too
      var existingPlaceholder = existingUser;
      if (existingPlaceholder == null && sanitizedPhone.isNotEmpty) {
        existingPlaceholder = await DbService().searchUserByPhone(sanitizedPhone);
      }
      if (existingPlaceholder != null && existingPlaceholder.isPlaceholder) {
        await DbService().claimPlaceholderHistory(existingPlaceholder.uid, uid);
      }

      _currentMockUser = newUser;
      _mockAuthController.add(newUser);
      return newUser;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    if (isFirebaseEnabled()) {
      await _firebaseAuth.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        print("Google sign out error: $e");
      }
    } else {
      _currentMockUser = null;
      _mockAuthController.add(null);
    }
  }

  /// Sign In with Google
  Future<UserModel> signInWithGoogle() async {
    if (isFirebaseEnabled()) {
      try {
        final UserCredential creds;
        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          creds = await _firebaseAuth.signInWithPopup(googleProvider);
        } else {
          // Ensure initialization for v7+ singleton
          await GoogleSignIn.instance.initialize();

          // Trigger Google Sign-In flow
          final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
          if (googleUser == null) {
            throw Exception("Google sign in cancelled by user");
          }

          // Obtain auth details from request
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );

          // Authenticate with Firebase
          creds = await _firebaseAuth.signInWithCredential(credential);
        }

        if (creds.user == null) {
          throw Exception("Firebase Google authentication failed");
        }

        final uid = creds.user!.uid;
        final email = (creds.user!.email ?? '').trim().toLowerCase();
        final displayName = creds.user!.displayName ?? 'Google User';

        // Check if user profile already exists
        var profile = await DbService().getUserProfile(uid);
        if (profile == null) {
          final newUser = UserModel(
            uid: uid,
            email: email,
            displayName: displayName,
            isPlaceholder: false,
            createdAt: DateTime.now(),
          );
          await DbService().createUserProfile(newUser);
          profile = newUser;

          // Check and claim placeholder history if they were previously invited
          final existingPlaceholder = await DbService().searchUserByEmail(email);
          if (existingPlaceholder != null && existingPlaceholder.isPlaceholder) {
            await DbService().claimPlaceholderHistory(existingPlaceholder.uid, uid);
          }
        }

        return profile;
      } catch (e) {
        throw Exception(e.toString());
      }
    } else {
      // Mock Google Sign-In flow for local preview
      await Future.delayed(const Duration(milliseconds: 300));
      
      final mockGoogleUser = UserModel(
        uid: 'google_mock_uid',
        email: 'google_user@example.com',
        displayName: 'Google Demo User',
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );

      DbService.addMockUser(mockGoogleUser);
      _currentMockUser = mockGoogleUser;
      _mockAuthController.add(mockGoogleUser);
      return mockGoogleUser;
    }
  }

  void setMockUser(UserModel? user) {
    _currentMockUser = user;
    _mockAuthController.add(user);
  }
}
