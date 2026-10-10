import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthController() {
    _init();
  }

  void _init() {
    _authSubscription = _repo.authStateChanges.listen((user) async {
      await _profileSubscription?.cancel();
      _currentUser = null;
      _isLoading = true;
      notifyListeners();

      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _profileSubscription = _repo.userProfileChanges(user.uid).listen(
        (profile) {
          _currentUser = profile;
          _errorMessage = profile == null
              ? 'Unable to load your profile right now.'
              : null;
          _isLoading = false;
          notifyListeners();
        },
        onError: (Object error) {
          _currentUser = null;
          _errorMessage = 'Unable to load your profile right now.';
          _isLoading = false;
          notifyListeners();
        },
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  bool isValidEmail(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  Future<bool> loginWithEmail(String email, String password) async {
    final sanitizedEmail = email.trim();
    final sanitizedPassword = password.trim();

    if (!isValidEmail(sanitizedEmail)) {
      _setError('Please enter a valid email address.');
      return false;
    }

    if (sanitizedPassword.length < 6) {
      _setError('Password must be at least 6 characters long.');
      return false;
    }

    _setLoading(true);
    try {
      await _repo.signInWithEmail(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_cleanError(e.toString()));
      return false;
    }
  }

  Future<bool> registerWithEmail(String name, String email, String password) async {
    final sanitizedName = name.trim();
    final sanitizedEmail = email.trim();
    final sanitizedPassword = password.trim();

    if (sanitizedName.isEmpty) {
      _setError('Please enter your full name.');
      return false;
    }

    if (!isValidEmail(sanitizedEmail)) {
      _setError('Please enter a valid email address.');
      return false;
    }

    if (sanitizedPassword.length < 6) {
      _setError('Password must be at least 6 characters long.');
      return false;
    }

    _setLoading(true);
    try {
      _currentUser = await _repo.signUpWithEmail(
        name: sanitizedName,
        email: sanitizedEmail,
        password: sanitizedPassword,
      );
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_cleanError(e.toString()));
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    try {
      _currentUser = await _repo.signInWithGoogle();
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _setError(_cleanError(e.toString()));
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _repo.signOut();
      _currentUser = null;
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _isLoading = false;
    notifyListeners();
  }

  String _cleanError(String msg) {
    const prefix = 'Exception: ';
    final cleaned = msg.replaceAll(prefix, '').trim();
    return cleaned.isNotEmpty ? cleaned : 'Something went wrong. Please try again.';
  }
}
