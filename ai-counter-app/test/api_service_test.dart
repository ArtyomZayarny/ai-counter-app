import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_counter_app/api_service.dart';

void main() {
  late File tempFile;

  setUp(() {
    tempFile = File('${Directory.systemTemp.path}/test_meter.jpg');
    tempFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]); // minimal JPEG
  });

  tearDown(() {
    if (tempFile.existsSync()) tempFile.deleteSync();
  });

  test('200 with valid JSON returns result', () async {
    final client = MockClient.streaming((request, _) async {
      final body = utf8.encode(jsonEncode({'result': '02340'}));
      return http.StreamedResponse(
        Stream.value(body),
        200,
      );
    });

    final result = await recognizeMeter(tempFile, client: client);
    expect(result, '02340');
  });

  test('422 with error field throws RecognitionException with message',
      () async {
    final client = MockClient.streaming((request, _) async {
      final body = utf8.encode(
          jsonEncode({'error': 'Wrong digit count', 'result': '0234'}));
      return http.StreamedResponse(
        Stream.value(body),
        422,
      );
    });

    expect(
      () => recognizeMeter(tempFile, client: client),
      throwsA(isA<RecognitionException>().having(
        (e) => e.message,
        'message',
        'Wrong digit count',
      )),
    );
  });

  test('500 without error field throws with "Unknown error"', () async {
    final client = MockClient.streaming((request, _) async {
      final body = utf8.encode(jsonEncode({'detail': 'Internal error'}));
      return http.StreamedResponse(
        Stream.value(body),
        500,
      );
    });

    expect(
      () => recognizeMeter(tempFile, client: client),
      throwsA(isA<RecognitionException>().having(
        (e) => e.message,
        'message',
        'Unknown error',
      )),
    );
  });

  test('SocketException throws "No connection to server"', () async {
    final client = MockClient.streaming((request, _) async {
      throw const SocketException('Connection refused');
    });

    expect(
      () => recognizeMeter(tempFile, client: client),
      throwsA(isA<RecognitionException>().having(
        (e) => e.message,
        'message',
        'No connection to server',
      )),
    );
  });
}
