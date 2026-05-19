import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});

class ApiClient {
  ApiClient(this._tokenStore)
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Accept': 'application/json'},
        ),
      );

  final TokenStore _tokenStore;
  final Dio _dio;

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
    final token = await _tokenStore.readAccessToken();
    try {
      return await _dio.request<T>(
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
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && retryOnUnauthorized) {
        final refreshed = await _refreshToken();
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
      throw ApiException.fromDio(error);
    }
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
      return true;
    } catch (_) {
      await _tokenStore.clear();
      return false;
    }
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
