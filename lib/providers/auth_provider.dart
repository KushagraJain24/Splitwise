import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/services/auth_service.dart';
import 'package:splitwise/services/db_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DbService _dbService = DbService();

  UserModel? _user;
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _authSubscription;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _isLoading = true;
    _isInitialized = false;
    notifyListeners();

    // Load cached user profile from SharedPreferences first
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (AuthService.isFirebaseEnabled()) {
          // If Firebase is enabled, only restore session if there is an active Firebase user session
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            final jsonStr = prefs.getString('cached_user_profile');
            if (jsonStr != null) {
              final Map<String, dynamic> userMap = json.decode(jsonStr);
              final cachedUser = UserModel.fromMap(userMap);
              
              if (cachedUser.uid == firebaseUser.uid) {
                _user = cachedUser;
                _isInitialized = true;
                _isLoading = false;
                notifyListeners();
              }
            }
            
            // If cache was empty/outdated but a Firebase session exists, create a temporary user
            if (_user == null) {
              _user = UserModel(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? '',
                displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
                isPlaceholder: false,
                createdAt: DateTime.now(),
              );
              _isInitialized = true;
              _isLoading = false;
              notifyListeners();
            }
          } else {
            // No current Firebase user, clean up cache
            await prefs.remove('cached_user_profile');
            _user = null;
          }
        } else {
          // Mock mode: restore mock user from SharedPreferences
          final jsonStr = prefs.getString('cached_user_profile');
          if (jsonStr != null) {
            final Map<String, dynamic> userMap = json.decode(jsonStr);
            final mockUser = UserModel.fromMap(userMap);
            DbService.addMockUser(mockUser);
            _authService.setMockUser(mockUser);
            _user = mockUser;
            _isInitialized = true;
            _isLoading = false;
            notifyListeners();
          } else {
            final savedUid = prefs.getString('mock_user_uid');
            final savedEmail = prefs.getString('mock_user_email');
            final savedName = prefs.getString('mock_user_name');

            if (savedUid != null && savedEmail != null && savedName != null) {
              final mockUser = UserModel(
                uid: savedUid,
                email: savedEmail,
                displayName: savedName,
                isPlaceholder: false,
                createdAt: DateTime.now(),
              );
              DbService.addMockUser(mockUser);
              _authService.setMockUser(mockUser);
              _user = mockUser;
              _isInitialized = true;
              _isLoading = false;
              notifyListeners();
            } else {
              _user = null;
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading cached user profile: $e");
      } finally {
        if (!_isInitialized) {
          _isLoading = false;
          _isInitialized = true;
          notifyListeners();
        }
      }
    });

    // Subscribe to auth state updates in the background
    _authSubscription = _authService.onAuthStateChanged.listen(
      (UserModel? userProfile) async {
        _user = userProfile;
        _isLoading = false;
        _errorMessage = null;
        _isInitialized = true;
        notifyListeners();

        // Update the cached user profile
        try {
          final prefs = await SharedPreferences.getInstance();
          if (userProfile != null) {
            await prefs.setString('cached_user_profile', json.encode(userProfile.toMap()));
          } else {
            await prefs.remove('cached_user_profile');
            if (!AuthService.isFirebaseEnabled()) {
              await prefs.remove('mock_user_uid');
              await prefs.remove('mock_user_email');
              await prefs.remove('mock_user_name');
            }
          }
        } catch (e) {
          debugPrint("Error saving/removing cached user: $e");
        }
      },
      onError: (err) {
        _errorMessage = err.toString();
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
      },
    );
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signIn(email, password);
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', json.encode(_user!.toMap()));
        if (!AuthService.isFirebaseEnabled()) {
          await prefs.setString('mock_user_uid', _user!.uid);
          await prefs.setString('mock_user_email', _user!.email);
          await prefs.setString('mock_user_name', _user!.displayName);
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String displayName, String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signUp(email, password, displayName, phone);
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', json.encode(_user!.toMap()));
        if (!AuthService.isFirebaseEnabled()) {
          await prefs.setString('mock_user_uid', _user!.uid);
          await prefs.setString('mock_user_email', _user!.email);
          await prefs.setString('mock_user_name', _user!.displayName);
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updatePhone(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final sanitizedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
      await _dbService.updateUserPhone(_user!.uid, sanitizedPhone);

      // Check and claim placeholder history if they were previously invited via this phone number
      final existingPlaceholder = await _dbService.searchUserByPhone(sanitizedPhone);
      if (existingPlaceholder != null && existingPlaceholder.isPlaceholder) {
        await _dbService.claimPlaceholderHistory(existingPlaceholder.uid, _user!.uid);
      }

      // Reload profile
      final updatedProfile = await _dbService.getUserProfile(_user!.uid);
      _user = updatedProfile;

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      if (_user != null) {
        await prefs.setString('cached_user_profile', json.encode(_user!.toMap()));
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAvatar(String avatarId) async {
    final photoUrl = 'avatar:$avatarId';
    if (_user != null) {
      _user = _user!.copyWith(photoUrl: photoUrl);
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', json.encode(_user!.toMap()));
      } catch (e) {
        debugPrint("Error caching updated avatar: $e");
      }

      // Perform DB write in background without blocking UI
      _dbService.updateUserAvatar(_user!.uid, avatarId).catchError((err) {
        debugPrint("Error updating user avatar in DB: $err");
      });
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithGoogle();
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', json.encode(_user!.toMap()));
        if (!AuthService.isFirebaseEnabled()) {
          await prefs.setString('mock_user_uid', _user!.uid);
          await prefs.setString('mock_user_email', _user!.email);
          await prefs.setString('mock_user_name', _user!.displayName);
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String? _mapFirebaseError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('cancelled') ||
        str.contains('canceled') ||
        str.contains('12501') ||
        str.contains('abort') ||
        str.contains('sign_in_canceled')) {
      return null;
    }

    final originalStr = e.toString();
    if (originalStr.contains('GoogleSignInException') || originalStr.contains('GoogleSignInExceptionCode')) {
      if (originalStr.contains('Account reauth failed') || originalStr.contains('[16]') || originalStr.contains('code 16')) {
        return 'Google Sign-In configuration error: Please make sure the SHA-1 fingerprint is added to your Firebase Console.';
      }
      return originalStr.replaceAll('Exception: ', '');
    }

    if (e is! FirebaseAuthException) {
      if (originalStr.startsWith('Exception: ')) {
        return originalStr.replaceFirst('Exception: ', '');
      }
      return originalStr;
    }
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential parameter is invalid or has expired.';
      default:
        return e.message ?? 'Authentication failed: ${e.code}';
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await _authService.signOut();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile');
      if (!AuthService.isFirebaseEnabled()) {
        await prefs.remove('mock_user_uid');
        await prefs.remove('mock_user_email');
        await prefs.remove('mock_user_name');
      }
    } catch (e) {
      debugPrint("Error clearing cached user on signout: $e");
    }

    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
