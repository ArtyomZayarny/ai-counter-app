import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
    try {
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
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on TimeoutException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on FormatException {
      throw AuthException('Server error. Please try again later.');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
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
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on TimeoutException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on FormatException {
      throw AuthException('Server error. Please try again later.');
    }
  }

  static Future<AuthResult> appleSignIn(String identityToken, {String? name}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/apple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity_token': identityToken,
          if (name != null) 'name': name,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = AuthResult.fromJson(json);
        await SecureStorage.setToken(result.accessToken);
        return result;
      }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(json['detail'] as String? ?? 'Apple sign-in failed');
      } on FormatException {
        throw AuthException('Server error (${response.statusCode}). Please try again.');
      }
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on TimeoutException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    }
  }

  static Future<void> deleteAccount() async {
    try {
      final token = await SecureStorage.getToken();
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/auth/account'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await SecureStorage.clearToken();
        return;
      }

      if (response.statusCode == 401) {
        await SecureStorage.clearToken();
        throw AuthException('Session expired. Please log in again.');
      }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(json['detail'] as String? ?? 'Failed to delete account');
      } on FormatException {
        throw AuthException('Server error. Please try again later.');
      }
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on TimeoutException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    }
  }

  static Future<AuthResult> googleSignIn(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'google_id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = AuthResult.fromJson(json);
        await SecureStorage.setToken(result.accessToken);
        return result;
      }

      // Handle non-JSON error responses (e.g. 500 Internal Server Error)
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(json['detail'] as String? ?? 'Google sign-in failed');
      } on FormatException {
        throw AuthException('Server error (${response.statusCode}). Please try again.');
      }
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    } on TimeoutException {
      throw AuthException('Could not connect to server. Check your internet connection.');
    }
  }
}
