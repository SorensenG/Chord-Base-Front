import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.html) 'google_sign_in_button_web.dart'
    as google_sign_in_button;

Widget buildGoogleSignInButton({
  required bool loading,
  required VoidCallback? onPressed,
}) {
  if (kIsWeb) {
    return google_sign_in_button.GoogleSignInButton(loading: loading);
  }

  return OutlinedButton.icon(
    onPressed: loading ? null : onPressed,
    icon: const Icon(Icons.g_mobiledata, size: 28),
    label: const Text('Continuar com Google'),
  );
}
