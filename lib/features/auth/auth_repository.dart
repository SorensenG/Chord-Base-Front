import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/users/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final access = jsonNullableText(data, 'accessToken');
    final refresh = jsonNullableText(data, 'refreshToken');
    if (access == null || refresh == null) {
      throw ApiException(
        'Resposta de login sem tokens. Campos recebidos: ${data.keys.join(', ')}',
      );
    }
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
    final user = await me().catchError(
      (_) => UserProfile(
        uuid: jsonText(data, 'uuid'),
        userName: jsonText(data, 'userName'),
        email: email,
        profileImageUrl: jsonNullableText(data, 'profileImageUrl'),
        roles: jsonStringList(data, 'roles'),
        active: jsonBool(data, 'active', fallback: true),
      ),
    );
    return AuthSession(accessToken: access, refreshToken: refresh, user: user);
  }

  Future<void> register({
    required String userName,
    required String email,
    required String password,
    String? profileImageUrl,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/users/register',
      data: {
        'userName': userName,
        'email': email,
        'password': password,
        'role': 'ROLE_USER',
        'profileImageUrl': profileImageUrl,
      },
    );
  }

  Future<UserProfile> updateProfileImage(String? profileImageUrl) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/users/me/profile-image',
      data: {'profileImageUrl': profileImageUrl},
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> me() async {
    final response = await _api.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile?> restoreSession() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;
    try {
      return await me();
    } catch (_) {
      await _tokens.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post<void>('/users/logout', data: {'refreshToken': refresh});
      }
    } finally {
      await _tokens.clear();
      await GoogleSignIn.instance.signOut().catchError((_) {});
    }
  }

  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb && AppConfig.googleWebClientId.isNotEmpty
          ? AppConfig.googleWebClientId
          : null,
      serverClientId: AppConfig.googleServerClientId.isNotEmpty
          ? AppConfig.googleServerClientId
          : null,
    );

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const ApiException(
        'Google Sign-In Web exige configuracao do Google Client ID e botao oficial do SDK.',
      );
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('Google nao retornou um idToken valido.');
    }

    // The current Spring API has no Google auth endpoint yet. Keep the complete
    // mobile/web sign-in capture here so the backend can later exchange idToken
    // for the same ChordBase JWT session used by email/password login.
    throw const ApiException(
      'Google conectado. Falta a API expor /users/google para trocar o idToken por uma sessao ChordBase.',
    );
  }
}

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) {
    unawaited(restore());
  }

  final AuthRepository _repository;

  Future<void> restore() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.restoreSession);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repository.login(email: email, password: password);
      return session.user;
    });
  }

  Future<void> register(
    String userName,
    String email,
    String password, {
    String? profileImageUrl,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.register(
        userName: userName,
        email: email,
        password: password,
        profileImageUrl: profileImageUrl,
      );
      final session = await _repository.login(email: email, password: password);
      return session.user;
    });
  }

  Future<void> updateProfileImage(String? profileImageUrl) async {
    final current = state.whenOrNull(data: (user) => user);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.updateProfileImage(profileImageUrl);
      return user;
    });
    if (state.hasError && current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> google() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.signInWithGoogle();
      return _repository.me();
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}
