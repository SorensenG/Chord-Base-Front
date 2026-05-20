import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chordbase/core/api_client.dart';
import 'package:chordbase/core/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TokenStore tokenStore;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStore = const TokenStore(FlutterSecureStorage());
  });

  test(
    'refreshes an expired access token before a protected request',
    () async {
      await tokenStore.saveTokens(
        accessToken: _jwtExpiringIn(const Duration(minutes: -1)),
        refreshToken: 'refresh-1',
      );

      final calls = <String>[];
      final dio = _testDio([
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.path, '/users/refresh');
          expect(options.data, {'refreshToken': 'refresh-1'});
          return _jsonResponse({
            'accessToken': 'fresh-access',
            'refreshToken': 'refresh-2',
          });
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.path, '/chord/chord-uuid');
          expect(options.headers['Authorization'], 'Bearer fresh-access');
          return _jsonResponse({
            'uuid': 'chord-uuid',
            'chordName': 'Samurai',
            'artist': 'Djavan',
            'chordPro': '[C]Oceano',
            'addBy': 'tester',
          });
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      final response = await api.get<Map<String, dynamic>>('/chord/chord-uuid');

      expect(response.data?['uuid'], 'chord-uuid');
      expect(await tokenStore.readAccessToken(), 'fresh-access');
      expect(await tokenStore.readRefreshToken(), 'refresh-2');
      expect(sessionExpiredSignals, 0);
      expect(calls, ['POST /users/refresh', 'GET /chord/chord-uuid']);
    },
  );

  test(
    'refreshes before a protected request when only a refresh token exists',
    () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'chordbase.refreshToken', value: 'refresh-1');

      final calls = <String>[];
      final dio = _testDio([
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.path, '/users/refresh');
          return _jsonResponse({
            'accessToken': 'fresh-access',
            'refreshToken': 'refresh-2',
          });
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.headers['Authorization'], 'Bearer fresh-access');
          return _jsonResponse([]);
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      final response = await api.get<List<dynamic>>('/setlists/me');

      expect(response.data, isEmpty);
      expect(await tokenStore.readAccessToken(), 'fresh-access');
      expect(await tokenStore.readRefreshToken(), 'refresh-2');
      expect(sessionExpiredSignals, 0);
      expect(calls, ['POST /users/refresh', 'GET /setlists/me']);
    },
  );

  test(
    'renews the access token and retries a protected request once',
    () async {
      await tokenStore.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-1',
      );

      final calls = <String>[];
      final dio = _testDio([
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.headers['Authorization'], 'Bearer expired-access');
          return _jsonResponse({'message': 'expired'}, 401);
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.path, '/users/refresh');
          return _jsonResponse({
            'accessToken': 'fresh-access',
            'refreshToken': 'refresh-2',
          });
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.headers['Authorization'], 'Bearer fresh-access');
          return _jsonResponse([]);
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      final response = await api.get<List<dynamic>>('/setlists/me');

      expect(response.data, isEmpty);
      expect(await tokenStore.readAccessToken(), 'fresh-access');
      expect(await tokenStore.readRefreshToken(), 'refresh-2');
      expect(sessionExpiredSignals, 0);
      expect(calls, [
        'GET /setlists/me',
        'POST /users/refresh',
        'GET /setlists/me',
      ]);
    },
  );

  test(
    'does not refresh or expire the session for public endpoint 401s',
    () async {
      await tokenStore.saveTokens(
        accessToken: 'existing-access',
        refreshToken: 'existing-refresh',
      );

      final dio = _testDio([
        (options) {
          expect(options.path, '/users/login');
          return _jsonResponse({'message': 'Invalid email or password'}, 401);
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      await expectLater(
        api.post<Map<String, dynamic>>(
          '/users/login',
          data: {'email': 'user@example.com', 'password': 'wrong-password'},
        ),
        throwsA(isA<ApiException>()),
      );

      expect(await tokenStore.readAccessToken(), 'existing-access');
      expect(await tokenStore.readRefreshToken(), 'existing-refresh');
      expect(sessionExpiredSignals, 0);
    },
  );

  test('clears the local session when refresh fails', () async {
    await tokenStore.saveTokens(
      accessToken: 'expired-access',
      refreshToken: 'expired-refresh',
    );

    final dio = _testDio([
      (_) => _jsonResponse({'message': 'expired'}, 401),
      (options) {
        expect(options.path, '/users/refresh');
        return _jsonResponse({'message': 'Unauthorized'}, 401);
      },
    ]);

    var sessionExpiredSignals = 0;
    final api = ApiClient(
      tokenStore,
      onSessionExpired: () => sessionExpiredSignals++,
      dio: dio,
    );

    await expectLater(
      api.get<List<dynamic>>('/setlists/me'),
      throwsA(isA<ApiException>()),
    );

    expect(await tokenStore.readAccessToken(), isNull);
    expect(await tokenStore.readRefreshToken(), isNull);
    expect(sessionExpiredSignals, 1);
  });

  test(
    'uses tokens refreshed by another instance instead of clearing them',
    () async {
      await tokenStore.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-used-elsewhere',
      );

      final calls = <String>[];
      final dio = _testDio([
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.headers['Authorization'], 'Bearer expired-access');
          return _jsonResponse({'message': 'expired'}, 401);
        },
        (options) async {
          calls.add('${options.method} ${options.path}');
          await tokenStore.saveTokens(
            accessToken: 'fresh-from-other-tab',
            refreshToken: 'refresh-from-other-tab',
          );
          return _jsonResponse({'message': 'Unauthorized'}, 401);
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(
            options.headers['Authorization'],
            'Bearer fresh-from-other-tab',
          );
          return _jsonResponse([]);
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      final response = await api.get<List<dynamic>>('/setlists/me');

      expect(response.data, isEmpty);
      expect(await tokenStore.readAccessToken(), 'fresh-from-other-tab');
      expect(await tokenStore.readRefreshToken(), 'refresh-from-other-tab');
      expect(sessionExpiredSignals, 0);
      expect(calls, [
        'GET /setlists/me',
        'POST /users/refresh',
        'GET /setlists/me',
      ]);
    },
  );

  test(
    'waits briefly for tokens refreshed by another instance before clearing',
    () async {
      await tokenStore.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-used-elsewhere',
      );

      final calls = <String>[];
      final dio = _testDio([
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(options.headers['Authorization'], 'Bearer expired-access');
          return _jsonResponse({'message': 'expired'}, 401);
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          Timer(const Duration(milliseconds: 20), () {
            unawaited(
              tokenStore.saveTokens(
                accessToken: 'fresh-from-other-tab',
                refreshToken: 'refresh-from-other-tab',
              ),
            );
          });
          return _jsonResponse({'message': 'Unauthorized'}, 401);
        },
        (options) {
          calls.add('${options.method} ${options.path}');
          expect(
            options.headers['Authorization'],
            'Bearer fresh-from-other-tab',
          );
          return _jsonResponse([]);
        },
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      final response = await api.get<List<dynamic>>('/setlists/me');

      expect(response.data, isEmpty);
      expect(await tokenStore.readAccessToken(), 'fresh-from-other-tab');
      expect(await tokenStore.readRefreshToken(), 'refresh-from-other-tab');
      expect(sessionExpiredSignals, 0);
      expect(calls, [
        'GET /setlists/me',
        'POST /users/refresh',
        'GET /setlists/me',
      ]);
    },
  );

  test(
    'expires the session when the retry after refresh is still unauthorized',
    () async {
      await tokenStore.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-1',
      );

      final dio = _testDio([
        (_) => _jsonResponse({'message': 'expired'}, 401),
        (_) => _jsonResponse({
          'accessToken': 'fresh-access',
          'refreshToken': 'refresh-2',
        }),
        (_) => _jsonResponse({'message': 'Unauthorized'}, 401),
      ]);

      var sessionExpiredSignals = 0;
      final api = ApiClient(
        tokenStore,
        onSessionExpired: () => sessionExpiredSignals++,
        dio: dio,
      );

      await expectLater(
        api.get<List<dynamic>>('/setlists/me'),
        throwsA(isA<ApiException>()),
      );

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
      expect(sessionExpiredSignals, 1);
    },
  );

  test('coalesces concurrent refreshes for expired access tokens', () async {
    await tokenStore.saveTokens(
      accessToken: _jwtExpiringIn(const Duration(minutes: -1)),
      refreshToken: 'refresh-1',
    );

    final calls = <String>[];
    final dio = _testDio([
      (options) async {
        calls.add('${options.method} ${options.path}');
        expect(options.path, '/users/refresh');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse({
          'accessToken': 'fresh-access',
          'refreshToken': 'refresh-2',
        });
      },
      (options) {
        calls.add('${options.method} ${options.path}');
        expect(options.headers['Authorization'], 'Bearer fresh-access');
        return _jsonResponse([]);
      },
      (options) {
        calls.add('${options.method} ${options.path}');
        expect(options.headers['Authorization'], 'Bearer fresh-access');
        return _jsonResponse([]);
      },
    ]);

    var sessionExpiredSignals = 0;
    final api = ApiClient(
      tokenStore,
      onSessionExpired: () => sessionExpiredSignals++,
      dio: dio,
    );

    final responses = await Future.wait([
      api.get<List<dynamic>>('/setlists/me'),
      api.get<List<dynamic>>('/chord/me'),
    ]);

    expect(responses.map((response) => response.data), everyElement(isEmpty));
    expect(await tokenStore.readAccessToken(), 'fresh-access');
    expect(await tokenStore.readRefreshToken(), 'refresh-2');
    expect(sessionExpiredSignals, 0);
    expect(calls, ['POST /users/refresh', 'GET /setlists/me', 'GET /chord/me']);
  });

  test('does not retry client-side API errors in Riverpod providers', () {
    expect(
      appProviderRetry(
        0,
        const ApiException('Sessao expirada.', statusCode: 401),
      ),
      isNull,
    );
    expect(
      appProviderRetry(0, const ApiException('Not found.', statusCode: 404)),
      isNull,
    );
    expect(
      appProviderRetry(0, const ApiException('Server error.', statusCode: 500)),
      isNotNull,
    );
  });
}

String _jwtExpiringIn(Duration offset) {
  final exp = DateTime.now().toUtc().add(offset).millisecondsSinceEpoch ~/ 1000;
  final header = _base64UrlJson({'alg': 'none', 'typ': 'JWT'});
  final payload = _base64UrlJson({'sub': 'user@example.com', 'exp': exp});
  return '$header.$payload.signature';
}

String _base64UrlJson(Object value) {
  return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
}

Dio _testDio(List<_RequestHandler> handlers) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080',
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.httpClientAdapter = _QueueAdapter(handlers);
  return dio;
}

ResponseBody _jsonResponse(Object body, [int statusCode = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

typedef _RequestHandler =
    FutureOr<ResponseBody> Function(RequestOptions options);

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._handlers);

  final List<_RequestHandler> _handlers;
  var _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_index >= _handlers.length) {
      throw StateError('Unexpected request: ${options.method} ${options.path}');
    }
    return _handlers[_index++](options);
  }

  @override
  void close({bool force = false}) {}
}
