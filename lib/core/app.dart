import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/auth_screen.dart';
import '../features/shell/app_shell.dart';
import 'theme.dart';

class ChordBaseApp extends StatelessWidget {
  const ChordBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChordBase',
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(sessionExpiredSignalProvider, (previous, next) {
      if (previous == null || next == previous) return;
      unawaited(ref.read(authControllerProvider.notifier).expireSession());
    });
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => AuthScreen(initialError: error.toString()),
      data: (user) => user == null ? const AuthScreen() : AppShell(user: user),
    );
  }
}
