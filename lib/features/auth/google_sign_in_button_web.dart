import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: loading,
      child: Opacity(
        opacity: loading ? 0.55 : 1,
        child: SizedBox(height: 44, child: Center(child: web.renderButton())),
      ),
    );
  }
}
