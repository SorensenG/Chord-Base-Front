import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Continuar com Google'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(240.0, 400.0);

        return SizedBox(
          height: 52,
          child: Center(
            child: SizedBox(
              width: width,
              height: 40,
              child: ClipRect(
                child: web.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    type: web.GSIButtonType.standard,
                    theme: web.GSIButtonTheme.outline,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.continueWith,
                    shape: web.GSIButtonShape.rectangular,
                    logoAlignment: web.GSIButtonLogoAlignment.left,
                    minimumWidth: width,
                    locale: 'pt-BR',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
