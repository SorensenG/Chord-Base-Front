import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/recent_activity_store.dart';
import '../../core/token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(recentActivityStoreProvider),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

class AuthRepository {
  AuthRepository(this._api, this._tokens, this._recentActivityStore);

  final ApiClient _api;
  final TokenStore _tokens;
  final RecentActivityStore _recentActivityStore;
  Future<void>? _googleInitialization;

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
        description: jsonNullableText(data, 'description'),
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
    String? description,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/users/register',
      data: {
        'userName': userName,
        'email': email,
        'password': password,
        'role': 'ROLE_USER',
        'profileImageUrl': profileImageUrl,
        'description': description,
      },
    );
  }

  Future<UserProfile> updateProfile({
    required String? profileImageUrl,
    required String? description,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/users/me/profile',
      data: {'profileImageUrl': profileImageUrl, 'description': description},
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateProfileImage(String? profileImageUrl) async {
    final current = await me();
    return updateProfile(
      profileImageUrl: profileImageUrl,
      description: current.description,
    );
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
    await _tokens.clear();
    await _recentActivityStore.clear();
    await GoogleSignIn.instance.signOut().catchError((_) {});
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post<void>('/users/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {}
  }

  Future<void> clearLocalSession() async {
    await _tokens.clear();
    await _recentActivityStore.clear();
    await GoogleSignIn.instance.signOut().catchError((_) {});
  }

  Future<void> initializeGoogleSignIn() {
    return _googleInitialization ??= GoogleSignIn.instance
        .initialize(
          clientId: kIsWeb && AppConfig.googleWebClientId.isNotEmpty
              ? AppConfig.googleWebClientId
              : null,
          serverClientId: AppConfig.googleServerClientId.isNotEmpty
              ? AppConfig.googleServerClientId
              : null,
        )
        .catchError((Object error) {
          _googleInitialization = null;
          throw error;
        });
  }

  Stream<GoogleSignInAuthenticationEvent> get googleAuthenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  Future<AuthSession> signInWithGoogle() async {
    await initializeGoogleSignIn();

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

    return _exchangeGoogleIdToken(idToken, fallbackEmail: account.email);
  }

  Future<AuthSession> signInWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    await initializeGoogleSignIn();

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('Google nao retornou um idToken valido.');
    }

    return _exchangeGoogleIdToken(idToken, fallbackEmail: account.email);
  }

  Future<AuthSession> _exchangeGoogleIdToken(
    String idToken, {
    required String fallbackEmail,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/users/google',
      data: {'idToken': idToken},
    );
    final data = response.data!;
    final access = jsonNullableText(data, 'accessToken');
    final refresh = jsonNullableText(data, 'refreshToken');
    if (access == null || refresh == null) {
      throw ApiException(
        'Resposta de login Google sem tokens. Campos recebidos: ${data.keys.join(', ')}',
      );
    }
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
    final user = await me().catchError(
      (_) => UserProfile(
        uuid: jsonText(data, 'uuid'),
        userName: jsonText(data, 'userName'),
        email: fallbackEmail,
        profileImageUrl: jsonNullableText(data, 'profileImageUrl'),
        description: jsonNullableText(data, 'description'),
        roles: jsonStringList(data, 'roles'),
        active: jsonBool(data, 'active', fallback: true),
      ),
    );
    return AuthSession(accessToken: access, refreshToken: refresh, user: user);
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
    String? description,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.register(
        userName: userName,
        email: email,
        password: password,
        profileImageUrl: profileImageUrl,
        description: description,
      );
      final session = await _repository.login(email: email, password: password);
      return session.user;
    });
  }

  Future<void> updateProfile({
    required String? profileImageUrl,
    required String? description,
  }) async {
    final current = state.whenOrNull(data: (user) => user);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.updateProfile(
        profileImageUrl: profileImageUrl,
        description: description,
      );
      return user;
    });
    if (state.hasError && current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> updateProfileImage(String? profileImageUrl) async {
    final current = state.whenOrNull(data: (user) => user);
    await updateProfile(
      profileImageUrl: profileImageUrl,
      description: current?.description,
    );
  }

  Future<void> google() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repository.signInWithGoogle();
      return session.user;
    });
  }

  Future<void> googleAccount(GoogleSignInAccount account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repository.signInWithGoogleAccount(account);
      return session.user;
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
    unawaited(_repository.logout());
  }

  Future<void> expireSession() async {
    await _repository.clearLocalSession();
    state = const AsyncValue.data(null);
  }
}
