import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme.dart';
import '../../core/user_messages.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/profile_avatar.dart';
import 'auth_repository.dart';
import 'google_sign_in_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _userName = TextEditingController();
  final _description = TextEditingController();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;
  var _register = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeGoogleSignIn());
  }

  @override
  void dispose() {
    unawaited(_googleAuthSubscription?.cancel());
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _userName.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(userMessage(error))));
        },
      );
    });

    final loading = ref.watch(authControllerProvider).isLoading;
    final colors = context.appColors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.ink, colors.surface],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 76)),
                    const SizedBox(height: 22),
                    Text(
                      _register ? 'Crie sua conta' : 'Entre no ChordBase',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cifras, setlists e repertorios com leitura pronta para ensaio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted),
                    ),
                    if (widget.initialError != null) ...[
                      const SizedBox(height: 16),
                      Text(widget.initialError!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    if (_register) ...[
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileAvatar(
                              userName: _userName.text,
                              profileImageUrl: _profileImageUrl,
                              radius: 44,
                              onTap: _pickProfileImage,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton.filled(
                                tooltip: 'Escolher foto',
                                onPressed: _pickProfileImage,
                                icon: const Icon(Icons.photo_camera_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _userName,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Nome de usuario',
                          hintText: 'ex: gabriel.dev',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'ex: voce@email.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        hintText: 'ex: sua senha',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar senha',
                          hintText: 'repita sua senha',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Descricao',
                          hintText:
                              'Compartilhe um pouco sobre voce, sua trajetoria na musica e seus gostos.',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(_register ? 'Criar e entrar' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    buildGoogleSignInButton(
                      loading: loading,
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).google(),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'Ja tenho conta'
                            : 'Criar nova conta ChordBase',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty) {
      _showMessage('Informe seu email.');
      return;
    }
    if (!isValidEmailText(email)) {
      _showMessage('Informe um email valido.');
      return;
    }
    if (password.isEmpty) {
      _showMessage('Informe sua senha.');
      return;
    }

    if (_register) {
      final userName = _userName.text.trim();
      if (userName.isEmpty) {
        _showMessage('Informe seu nome de usuario.');
        return;
      }
      if (password != _confirmPassword.text) {
        _showMessage('As senhas nao conferem.');
        return;
      }
      if (_description.text.trim().length > 500) {
        _showMessage('A descricao deve ter no maximo 500 caracteres.');
        return;
      }
      await controller.register(
        userName,
        email,
        password,
        profileImageUrl: _profileImageUrl,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
    } else {
      await controller.login(email, password);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.initializeGoogleSignIn();
      _googleAuthSubscription = repository.googleAuthenticationEvents.listen(
        _handleGoogleAuthenticationEvent,
        onError: (Object error) {
          if (!mounted) return;
          _showMessage(userMessage(error));
        },
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(userMessage(error));
    }
  }

  void _handleGoogleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(user: final user):
        unawaited(
          ref.read(authControllerProvider.notifier).googleAccount(user),
        );
      case GoogleSignInAuthenticationEventSignOut():
        break;
    }
  }

  Future<void> _pickProfileImage() async {
    final image = await pickProfileImageDataUrl();
    if (!mounted || image == null) return;
    setState(() => _profileImageUrl = image);
  }
}
