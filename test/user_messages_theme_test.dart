import 'package:chordbase/core/api_client.dart';
import 'package:chordbase/core/models.dart';
import 'package:chordbase/core/theme.dart';
import 'package:chordbase/core/user_messages.dart';
import 'package:chordbase/shared/widgets/app_layout.dart';
import 'package:chordbase/shared/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps common API errors to user-friendly messages', () {
    expect(
      userMessage(
        const ApiException('Invalid email or password', statusCode: 401),
      ),
      'Email ou senha incorretos.',
    );
    expect(
      userMessage(const ApiException('Email already in use', statusCode: 400)),
      'Este email já está em uso.',
    );
    expect(
      userMessage(
        const ApiException('UserName already in use', statusCode: 400),
      ),
      'Este nome de usuário já está em uso.',
    );
    expect(
      userMessage(
        const ApiException('User not found with id: 1', statusCode: 404),
      ),
      'Não encontramos esse item.',
    );
  });

  test('validates email text locally', () {
    expect(isValidEmailText('user@example.com'), isTrue);
    expect(isValidEmailText('User@Example.COM'), isTrue);
    expect(isValidEmailText('user@example'), isFalse);
    expect(isValidEmailText('user name@example.com'), isFalse);
  });

  test('parses user description from API payloads', () {
    final user = UserProfile.fromJson({
      'uuid': '1',
      'userName': 'gabriel',
      'email': 'gabriel@example.com',
      'profileImageUrl': null,
      'description': 'Guitarrista e cantor.',
      'roles': ['ROLE_USER'],
      'active': true,
    });

    expect(user.description, 'Guitarrista e cantor.');
  });

  test('persists theme preference locally', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(themeModeControllerProvider),
      AppThemePreference.system,
    );
    await container
        .read(themeModeControllerProvider.notifier)
        .setPreference(AppThemePreference.light);

    expect(
      container.read(themeModeControllerProvider),
      AppThemePreference.light,
    );

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
      webOptions: WebOptions(
        dbName: 'chordbase_secure',
        publicKey: 'chordbase',
      ),
    );
    expect(await storage.read(key: 'chordbase.themeMode'), 'light');
  });

  testWidgets('keeps page header actions in the top row on compact widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: PageHeader(
              title: 'Ola, gabriel',
              subtitle:
                  'Gerencie suas cifras e setlists, e continue tocando de onde parou.',
              leading: const AppLogo(size: 42),
              actions: [
                IconButton(
                  tooltip: 'Pendencias',
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final titleTop = tester.getTopLeft(find.text('Ola, gabriel')).dy;
    final iconTop = tester
        .getTopLeft(find.byIcon(Icons.notifications_none_rounded))
        .dy;

    expect((iconTop - titleTop).abs(), lessThan(24));
  });
}
