import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    webOptions: WebOptions(dbName: 'chordbase_secure', publicKey: 'chordbase'),
  );
  return const TokenStore(storage);
});

final sessionExpiredSignalProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    onSessionExpired: () {
      ref.read(sessionExpiredSignalProvider.notifier).state++;
    },
  );
});

Duration? appProviderRetry(int retryCount, Object error) {
  final statusCode = error is ApiException ? error.statusCode : null;
  if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

class ApiClient {
  ApiClient(
    this._tokenStore, {
    required VoidCallback onSessionExpired,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppConfig.apiBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               headers: const {'Accept': 'application/json'},
             ),
           ),
       _onSessionExpired = onSessionExpired;

  final TokenStore _tokenStore;
  final Dio _dio;
  final VoidCallback _onSessionExpired;
  static const _refreshSkew = Duration(seconds: 45);
  Future<bool>? _refreshFuture;
  bool _sessionExpiredNotified = false;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _request<T>('GET', path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _request<T>('POST', path, data: data);

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _request<T>('PUT', path, data: data);

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _request<T>('DELETE', path, data: data);

  Future<Response<T>> multipart<T>(String path, FormData data) =>
      _request<T>('POST', path, data: data);

  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool retryOnUnauthorized = true,
  }) async {
    final protectedPath = !_isPublicPath(path);
    var token = await _tokenStore.readAccessToken();
    if (retryOnUnauthorized &&
        protectedPath &&
        (token == null || token.isEmpty || _shouldRefreshAccessToken(token))) {
      final refreshed = await _refreshTokenOnce();
      if (!refreshed) {
        await _expireSession();
        throw const ApiException(
          'Sessao expirada. Entre novamente.',
          statusCode: 401,
        );
      }
      token = await _tokenStore.readAccessToken();
    }

    try {
      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      _sessionExpiredNotified = false;
      return response;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && protectedPath) {
        if (retryOnUnauthorized) {
          final refreshed = await _refreshTokenOnce();
          if (refreshed) {
            return _request<T>(
              method,
              path,
              data: data,
              queryParameters: queryParameters,
              retryOnUnauthorized: false,
            );
          }
        }
        await _expireSession();
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> _refreshTokenOnce() {
    final current = _refreshFuture;
    if (current != null) return current;

    final future = _refreshToken();
    _refreshFuture = future;
    return future.whenComplete(() => _refreshFuture = null);
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      if (access == null || refresh == null) return false;
      await _tokenStore.saveTokens(accessToken: access, refreshToken: refresh);
      _sessionExpiredNotified = false;
      return true;
    } catch (_) {
      if (await _hasNewerStoredSession(refreshToken)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await _hasNewerStoredSession(refreshToken)) {
        return true;
      }
      await _tokenStore.clear();
      return false;
    }
  }

  Future<bool> _hasNewerStoredSession(String refreshToken) async {
    final latestAccessToken = await _tokenStore.readAccessToken();
    final latestRefreshToken = await _tokenStore.readRefreshToken();
    return latestAccessToken != null &&
        latestAccessToken.isNotEmpty &&
        latestRefreshToken != null &&
        latestRefreshToken.isNotEmpty &&
        latestRefreshToken != refreshToken;
  }

  Future<void> _expireSession() async {
    await _tokenStore.clear();
    if (_sessionExpiredNotified) return;
    _sessionExpiredNotified = true;
    _onSessionExpired();
  }

  bool _isPublicPath(String path) {
    return path == '/users/login' ||
        path == '/users/google' ||
        path == '/users/register' ||
        path == '/users/refresh' ||
        path == '/users/logout';
  }

  bool _shouldRefreshAccessToken(String token) {
    final expiresAt = _jwtExpiration(token);
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(_refreshSkew));
  }

  DateTime? _jwtExpiration(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return null;
      final exp = json['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    var message = error.message ?? 'Falha de comunicacao com a API.';
    if (data is Map<String, dynamic>) {
      message =
          data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String? ??
          message;
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    }
    return ApiException(message, statusCode: error.response?.statusCode);
  }

  @override
  String toString() => message;
}
