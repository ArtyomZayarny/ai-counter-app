import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_counter_app/api_service.dart';

const _testMeterId = 'test-meter-id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File tempFile;

  setUp(() {
    // Mock the flutter_secure_storage platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') return null; // no token stored
        return null;
      },
    );

    tempFile = File('${Directory.systemTemp.path}/test_meter.jpg');
    tempFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]); // minimal JPEG
  });

  tearDown(() {
    if (tempFile.existsSync()) tempFile.deleteSync();
  });

  test('200 with valid JSON returns result', () async {
    final client = MockClient.streaming((request, _) async {
      final body = utf8.encode(
          jsonEncode({'result': '02340', 'reading_id': 'abc-123'}));
      return http.StreamedResponse(
        Stream.value(body),
        200,
      );
    });

    final result =
        await recognizeMeter(tempFile, _testMeterId, client: client);
    expect(result['result'], '02340');
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
      () => recognizeMeter(tempFile, _testMeterId, client: client),
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
      () => recognizeMeter(tempFile, _testMeterId, client: client),
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
      () => recognizeMeter(tempFile, _testMeterId, client: client),
      throwsA(isA<RecognitionException>().having(
        (e) => e.message,
        'message',
        'No connection to server',
      )),
    );
  });

  group('checkHealth', () {
    test('returns true when server responds 200', () async {
      final client = MockClient((request) async {
        return http.Response('{"status": "ok"}', 200);
      });

      final result = await checkHealth(client: client);
      expect(result, true);
    });

    test('returns false when server responds 500', () async {
      final client = MockClient((request) async {
        return http.Response('error', 500);
      });

      final result = await checkHealth(client: client);
      expect(result, false);
    });

    test('returns false on connection error', () async {
      final client = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final result = await checkHealth(client: client);
      expect(result, false);
    });
  });
}
