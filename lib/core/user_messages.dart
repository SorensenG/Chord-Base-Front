import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

String userMessage(Object error, {String? fallback}) {
  if (error is ApiException) {
    final message = _messageFromApiException(error);
    if (message != null) return message;
  }
  if (error is DioException) {
    return _messageFromDio(error);
  }

  final text = error.toString();
  return _messageFromRawText(text) ?? fallback ?? text;
}

void showUserMessage(BuildContext context, Object error, {String? fallback}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(userMessage(error, fallback: fallback))),
  );
}

String? _messageFromApiException(ApiException error) {
  final raw = error.message;
  final normalized = raw.toLowerCase();

  if (error.statusCode == 401) {
    if (normalized.contains('sessao') || normalized.contains('session')) {
      return 'Sua sessão expirou. Entre novamente.';
    }
    return 'Email ou senha incorretos.';
  }
  if (error.statusCode == 403) {
    return 'Você não tem permissão para fazer isso.';
  }
  if (error.statusCode == 404) {
    return 'Não encontramos esse item.';
  }
  if (error.statusCode != null && error.statusCode! >= 500) {
    return 'A API encontrou um problema. Tente novamente em instantes.';
  }

  return _messageFromRawText(raw);
}

String _messageFromDio(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'A conexão demorou demais. Verifique sua internet e tente de novo.',
    DioExceptionType.connectionError =>
      'Não foi possível conectar. Verifique sua internet e tente de novo.',
    _ => 'Não foi possível concluir a ação. Tente novamente.',
  };
}

String? _messageFromRawText(String text) {
  final normalized = text.toLowerCase();
  if (normalized.contains('email already in use')) {
    return 'Este email já está em uso.';
  }
  if (normalized.contains('username already in use') ||
      normalized.contains('user name already in use')) {
    return 'Este nome de usuário já está em uso.';
  }
  if (normalized.contains('email must be valid')) {
    return 'Informe um email válido.';
  }
  if (normalized.contains('email must not be empty')) {
    return 'Informe seu email.';
  }
  if (normalized.contains('password must not be empty')) {
    return 'Informe sua senha.';
  }
  if (normalized.contains('username must not be empty')) {
    return 'Informe seu nome de usuário.';
  }
  if (normalized.contains('username must have between')) {
    return 'O nome de usuário deve ter entre 3 e 30 caracteres.';
  }
  if (normalized.contains('username can contain only')) {
    return 'Use apenas letras, números, ponto e underline no nome de usuário.';
  }
  if (normalized.contains('description must have at most')) {
    return 'A descrição deve ter no máximo 500 caracteres.';
  }
  if (normalized.contains('file must not be empty')) {
    return 'Envie um arquivo válido.';
  }
  if (normalized.contains('only published chords can be added')) {
    return 'Só cifras publicadas podem entrar em setlists.';
  }
  if (normalized.contains('setlist owner cannot be added')) {
    return 'O dono da setlist já faz parte dela.';
  }
  if (normalized.contains('only collaborative setlists')) {
    return 'Apenas setlists colaborativas aceitam convites.';
  }
  if (normalized.contains('not allowed')) {
    return 'Você não tem permissão para fazer isso.';
  }
  if (normalized.contains('not found')) {
    return 'Não encontramos esse item.';
  }
  return null;
}

bool isValidEmailText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 254 || trimmed.contains(' ')) {
    return false;
  }
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(trimmed);
}
