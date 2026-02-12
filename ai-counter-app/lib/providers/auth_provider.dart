import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = true;
  String? _photoUrl;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get photoUrl => _photoUrl;

  Future<void> checkAuth() async {
    _loading = true;
    notifyListeners();

    final token = await SecureStorage.getToken();
    if (token == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    // Token exists — we assume it's valid. If any API call returns 401,
    // we'll handle it by logging out.
    _loading = false;
    notifyListeners();
  }

  Future<void> register(String email, String password, String name) async {
    final result = await AuthService.register(email, password, name);
    _user = result.user;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await AuthService.login(email, password);
    _user = result.user;
    notifyListeners();
  }

  Future<void> googleSignIn() async {
    final gsi = GoogleSignIn(
      scopes: ['email'],
      serverClientId:
          '210000571965-hd499r32as02qafa2ae7jsin35clh1tn.apps.googleusercontent.com',
    );
    final googleUser = await gsi.signIn();
    if (googleUser == null) return;

    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw AuthException('No Google ID token');

    final result = await AuthService.googleSignIn(idToken);
    _user = result.user;
    _photoUrl = googleUser.photoUrl;
    notifyListeners();
  }

  Future<void> logout() async {
    await SecureStorage.clearToken();
    // Sign out of Google so the account picker shows next time
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    _user = null;
    _photoUrl = null;
    notifyListeners();
  }

  void handle401() {
    logout();
  }
}
