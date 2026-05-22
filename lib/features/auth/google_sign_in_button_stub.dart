import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Continuar com Google'),
    );
  }
}
