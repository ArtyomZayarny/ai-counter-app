import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models/bill.dart';
import 'models/meter.dart';
import 'models/reading.dart';
import 'models/tariff.dart';
import 'services/secure_storage.dart';

class RecognitionException implements Exception {
  final String message;
  RecognitionException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {}

Future<Map<String, String>> _authHeaders() async {
  final token = await SecureStorage.getToken();
  return {
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

void _check401(int statusCode) {
  if (statusCode == 401) throw UnauthorizedException();
}

// --- Recognize ---

Future<Map<String, dynamic>> recognizeMeter(
  File imageFile,
  String meterId, {
  http.Client? client,
}) async {
  final uri = Uri.parse('$apiBaseUrl/recognize');
  final request = http.MultipartRequest('POST', uri)
    ..fields['meter_id'] = meterId
    ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final headers = await _authHeaders();
  request.headers.addAll(headers);

  final http.StreamedResponse streamed;
  final c = client ?? http.Client();
  try {
    streamed = await c.send(request).timeout(const Duration(seconds: 15));
  } on SocketException {
    throw RecognitionException('No connection to server');
  }

  _check401(streamed.statusCode);

  final body = await streamed.stream.bytesToString();
  final json = jsonDecode(body) as Map<String, dynamic>;

  if (streamed.statusCode == 200) {
    return json; // {result, reading_id}
  }

  final error = json['error'] as String? ?? 'Unknown error';
  throw RecognitionException(error);
}

// --- Health ---

Future<bool> checkHealth({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final response = await c
        .get(Uri.parse('$apiBaseUrl/health'))
        .timeout(const Duration(seconds: 3));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// --- Meters ---

Future<List<Meter>> getMeters() async {
  final headers = await _authHeaders();
  final response = await http
      .get(Uri.parse('$apiBaseUrl/meters'), headers: headers)
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  final list = jsonDecode(response.body) as List;
  return list.map((j) => Meter.fromJson(j as Map<String, dynamic>)).toList();
}

Future<Meter> createMeter({
  required String propertyId,
  required String utilityType,
  required String name,
}) async {
  final headers = await _authHeaders();
  headers['Content-Type'] = 'application/json';
  final response = await http
      .post(
        Uri.parse('$apiBaseUrl/meters'),
        headers: headers,
        body: jsonEncode({
          'property_id': propertyId,
          'utility_type': utilityType,
          'name': name,
        }),
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  return Meter.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}

// --- Readings ---

Future<Reading> createReading({
  required String meterId,
  required int value,
}) async {
  final headers = await _authHeaders();
  final response = await http
      .post(
        Uri.parse('$apiBaseUrl/readings'),
        headers: headers,
        body: {'meter_id': meterId, 'value': value.toString()},
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  if (response.statusCode == 201) {
    return Reading.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  throw RecognitionException(json['detail'] as String? ?? 'Failed to save reading');
}

Future<List<Reading>> getReadings(String meterId,
    {int limit = 50, int offset = 0}) async {
  final headers = await _authHeaders();
  final response = await http
      .get(
        Uri.parse(
            '$apiBaseUrl/readings?meter_id=$meterId&limit=$limit&offset=$offset'),
        headers: headers,
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  final list = jsonDecode(response.body) as List;
  return list.map((j) => Reading.fromJson(j as Map<String, dynamic>)).toList();
}

Future<void> deleteReading(String readingId) async {
  final headers = await _authHeaders();
  final response = await http
      .delete(Uri.parse('$apiBaseUrl/readings/$readingId'), headers: headers)
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);
}

// --- Tariffs ---

Future<List<Tariff>> getTariffs(String meterId) async {
  final headers = await _authHeaders();
  final response = await http
      .get(Uri.parse('$apiBaseUrl/tariffs?meter_id=$meterId'), headers: headers)
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  final list = jsonDecode(response.body) as List;
  return list.map((j) => Tariff.fromJson(j as Map<String, dynamic>)).toList();
}

Future<Tariff> createTariff({
  required String meterId,
  required double pricePerUnit,
  required String effectiveFrom,
  String currency = 'EUR',
}) async {
  final headers = await _authHeaders();
  headers['Content-Type'] = 'application/json';
  final response = await http
      .post(
        Uri.parse('$apiBaseUrl/tariffs'),
        headers: headers,
        body: jsonEncode({
          'meter_id': meterId,
          'price_per_unit': pricePerUnit,
          'effective_from': effectiveFrom,
          'currency': currency,
        }),
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  return Tariff.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}

// --- Bills ---

Future<List<Bill>> getBills(String meterId,
    {int limit = 50, int offset = 0}) async {
  final headers = await _authHeaders();
  final response = await http
      .get(
        Uri.parse(
            '$apiBaseUrl/bills?meter_id=$meterId&limit=$limit&offset=$offset'),
        headers: headers,
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  final list = jsonDecode(response.body) as List;
  return list.map((j) => Bill.fromJson(j as Map<String, dynamic>)).toList();
}

Future<Bill> createBill({
  required String meterId,
  required String readingFromId,
  required String readingToId,
  required double tariffPerUnit,
  String currency = 'EUR',
}) async {
  final headers = await _authHeaders();
  headers['Content-Type'] = 'application/json';
  final response = await http
      .post(
        Uri.parse('$apiBaseUrl/bills'),
        headers: headers,
        body: jsonEncode({
          'meter_id': meterId,
          'reading_from_id': readingFromId,
          'reading_to_id': readingToId,
          'tariff_per_unit': tariffPerUnit,
          'currency': currency,
        }),
      )
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);

  return Bill.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}

Future<void> deleteBill(String billId) async {
  final headers = await _authHeaders();
  final response = await http
      .delete(Uri.parse('$apiBaseUrl/bills/$billId'), headers: headers)
      .timeout(const Duration(seconds: 10));

  _check401(response.statusCode);
}
