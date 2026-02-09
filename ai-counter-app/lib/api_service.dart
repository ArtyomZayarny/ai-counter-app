import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class RecognitionException implements Exception {
  final String message;
  RecognitionException(this.message);

  @override
  String toString() => message;
}

Future<String> recognizeMeter(File imageFile, {http.Client? client}) async {
  final uri = Uri.parse('$apiBaseUrl/recognize');
  final request = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final http.StreamedResponse streamed;
  final c = client ?? http.Client();
  try {
    streamed = await c.send(request).timeout(const Duration(seconds: 15));
  } on SocketException {
    throw RecognitionException('No connection to server');
  }

  final body = await streamed.stream.bytesToString();
  final json = jsonDecode(body) as Map<String, dynamic>;

  if (streamed.statusCode == 200) {
    return json['result'] as String;
  }

  final error = json['error'] as String? ?? 'Unknown error';
  throw RecognitionException(error);
}
