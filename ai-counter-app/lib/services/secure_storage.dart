import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _onboardingKey = 'has_seen_onboarding';
  static const _currencyKey = 'preferred_currency';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> setToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<bool> hasSeenOnboarding() async {
    final value = await _storage.read(key: _onboardingKey);
    return value == 'true';
  }

  static Future<void> setOnboardingSeen() =>
      _storage.write(key: _onboardingKey, value: 'true');

  static Future<String?> getCurrency() => _storage.read(key: _currencyKey);

  static Future<void> setCurrency(String code) =>
      _storage.write(key: _currencyKey, value: code);
}
