import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/profile_avatar.dart';
import 'auth_repository.dart';

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
  var _register = false;
  String? _profileImageUrl;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _userName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    final loading = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ink, Color(0xFF142229)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 108)),
                  const SizedBox(height: 26),
                  Text(
                    _register ? 'Crie sua conta' : 'Entre no ChordBase',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cifras, setlists e repertorios com leitura pronta para ensaio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  if (widget.initialError != null) ...[
                    const SizedBox(height: 16),
                    Text(widget.initialError!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 28),
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
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text(_register ? 'Criar e entrar' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .google(),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continuar com Google'),
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
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    if (_register) {
      if (_password.text != _confirmPassword.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('As senhas nao conferem.')),
        );
        return;
      }
      await controller.register(
        _userName.text.trim(),
        _email.text.trim(),
        _password.text,
        profileImageUrl: _profileImageUrl,
      );
    } else {
      await controller.login(_email.text.trim(), _password.text);
    }
  }

  Future<void> _pickProfileImage() async {
    final image = await pickProfileImageDataUrl();
    if (!mounted || image == null) return;
    setState(() => _profileImageUrl = image);
  }
}
