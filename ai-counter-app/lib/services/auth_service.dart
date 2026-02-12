import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user.dart';
import '../services/secure_storage.dart';

class AuthResult {
  final String accessToken;
  final User user;

  AuthResult({required this.accessToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static Future<AuthResult> register(
      String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      final result = AuthResult.fromJson(json);
      await SecureStorage.setToken(result.accessToken);
      return result;
    }

    throw AuthException(json['detail'] as String? ?? 'Registration failed');
  }

  static Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final result = AuthResult.fromJson(json);
      await SecureStorage.setToken(result.accessToken);
      return result;
    }

    throw AuthException(json['detail'] as String? ?? 'Login failed');
  }

  static Future<AuthResult> googleSignIn(String idToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'google_id_token': idToken}),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final result = AuthResult.fromJson(json);
      await SecureStorage.setToken(result.accessToken);
      return result;
    }

    throw AuthException(json['detail'] as String? ?? 'Google sign-in failed');
  }
}
