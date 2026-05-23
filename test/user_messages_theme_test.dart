import 'package:chordbase/core/api_client.dart';
import 'package:chordbase/core/models.dart';
import 'package:chordbase/core/theme.dart';
import 'package:chordbase/core/tutorial.dart';
import 'package:chordbase/core/user_messages.dart';
import 'package:chordbase/features/chords/chords_screen.dart';
import 'package:chordbase/features/chords/chords_repository.dart';
import 'package:chordbase/features/shell/app_shell.dart';
import 'package:chordbase/shared/widgets/app_layout.dart';
import 'package:chordbase/shared/widgets/app_logo.dart';
import 'package:file_picker/file_picker.dart';
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

  test('maps chord import upload errors to user-friendly messages', () {
    expect(
      userMessage(const ApiException('UNSUPPORTED_EXTENSION', statusCode: 400)),
      chordDocumentsOnlyMessage,
    );
    expect(
      userMessage(const ApiException('INVALID_IMAGE', statusCode: 422)),
      chordDocumentsOnlyMessage,
    );
    expect(
      userMessage(
        const ApiException(
          'Não consegui identificar uma cifra nessa imagem. Envie uma foto mais nítida, PDF ou TXT.',
          statusCode: 422,
        ),
      ),
      chordDocumentsOnlyMessage,
    );
    expect(
      userMessage(
        const ApiException(
          'Não foi possível extrair texto do arquivo.',
          statusCode: 422,
        ),
      ),
      'Não consegui ler texto desse arquivo. Tente um PDF com texto selecionável ou envie TXT.',
    );
    expect(
      userMessage(
        const ApiException(
          'Arquivo excede o tamanho máximo permitido.',
          statusCode: 413,
        ),
      ),
      chordUploadTooLargeMessage,
    );
    expect(
      userMessage(
        const ApiException('Maximum upload size exceeded', statusCode: 400),
      ),
      chordUploadTooLargeMessage,
    );
    expect(
      userMessage(
        const ApiException(
          'MaxUploadSizeExceededException: request rejected',
          statusCode: 400,
        ),
      ),
      chordUploadTooLargeMessage,
    );
    expect(
      userMessage(const ApiException('UPLOAD_TOO_LARGE', statusCode: 400)),
      chordUploadTooLargeMessage,
    );
    expect(
      userMessage(const ApiException('OCR_BUSY', statusCode: 422)),
      'Outro documento está sendo processado. Aguarde um instante e tente novamente.',
    );
    expect(
      userMessage(
        const ApiException(
          'O processamento de imagens está ocupado. Tente novamente em instantes.',
          statusCode: 400,
        ),
      ),
      'Outro documento está sendo processado. Aguarde um instante e tente novamente.',
    );
    expect(
      userMessage(
        const ApiException(
          'O processamento de documentos está ocupado. Tente novamente em instantes.',
          statusCode: 400,
        ),
      ),
      'Outro documento está sendo processado. Aguarde um instante e tente novamente.',
    );
    expect(
      userMessage(
        const ApiException('IMAGE_DIMENSIONS_TOO_LARGE', statusCode: 422),
      ),
      chordDocumentsOnlyMessage,
    );
    expect(
      userMessage(
        const ApiException(
          'A imagem é grande demais para processamento seguro. Envie uma foto menor ou um PDF.',
          statusCode: 400,
        ),
      ),
      chordDocumentsOnlyMessage,
    );
  });

  test('resolves chord upload content types', () {
    expect(contentTypeForChordUpload('song.pdf').mimeType, 'application/pdf');
    expect(contentTypeForChordUpload('song.txt').mimeType, 'text/plain');
    expect(
      contentTypeForChordUpload('song.jpg').mimeType,
      'application/octet-stream',
    );
  });

  test('accepts only PDF and TXT chord imports locally', () {
    expect(
      isSupportedChordImportFile(PlatformFile(name: 'song.pdf', size: 1)),
      isTrue,
    );
    expect(
      isSupportedChordImportFile(PlatformFile(name: 'song.TXT', size: 1)),
      isTrue,
    );
    expect(
      isSupportedChordImportFile(PlatformFile(name: 'song.jpg', size: 1)),
      isFalse,
    );
  });

  test('validates chord upload size locally', () {
    expect(
      isChordUploadTooLarge(
        PlatformFile(name: 'song.pdf', size: maxChordUploadSizeBytes + 1),
      ),
      isTrue,
    );
    expect(
      isChordUploadTooLarge(
        PlatformFile(name: 'song.pdf', size: maxChordUploadSizeBytes),
      ),
      isFalse,
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

  test('runs first-use tutorial only until completed locally', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final controller = container.read(tutorialControllerProvider.notifier);
    await controller.startAutomaticTourIfNeeded();

    expect(container.read(tutorialControllerProvider).isRunning, isTrue);
    expect(container.read(tutorialControllerProvider).stepIndex, 0);

    await controller.nextStep();
    expect(container.read(tutorialControllerProvider).stepIndex, 1);

    await controller.skipTour();
    expect(container.read(tutorialControllerProvider).completed, isTrue);

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
      webOptions: WebOptions(
        dbName: 'chordbase_secure',
        publicKey: 'chordbase',
      ),
    );
    expect(await storage.read(key: TutorialController.storageKey), 'true');

    await controller.startAutomaticTourIfNeeded();
    expect(container.read(tutorialControllerProvider).isRunning, isFalse);

    await controller.startManualTour();
    expect(container.read(tutorialControllerProvider).isRunning, isTrue);
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

  testWidgets(
    'stacks page header actions below text when requested on mobile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PageHeader(
                title: 'Revisar cifra',
                subtitle: 'Confira o ChordPro extraido antes de publicar.',
                stackCompactActions: true,
                actions: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Publicar cifra'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ver modo reproducao'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final subtitleBottom = tester
          .getBottomLeft(
            find.text('Confira o ChordPro extraido antes de publicar.'),
          )
          .dy;
      final publishTop = tester.getTopLeft(find.text('Publicar cifra')).dy;
      final playerTop = tester.getTopLeft(find.text('Ver modo reproducao')).dy;

      expect(publishTop, greaterThan(subtitleBottom));
      expect(playerTop, greaterThan(publishTop + 8));
    },
  );

  testWidgets('tutorial overlay advances and skips from visible controls', (
    tester,
  ) async {
    var nextCount = 0;
    var skipCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Stack(
          children: [
            TutorialOverlay(
              stepIndex: 0,
              onBack: () {},
              onNext: () => nextCount++,
              onSkip: () => skipCount++,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Comece pela Home'), findsOneWidget);
    await tester.tap(find.text('Proximo'));
    await tester.tap(find.text('Pular'));

    expect(nextCount, 1);
    expect(skipCount, 1);
  });

  testWidgets('review screen stacks status note on mobile widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const ProviderScope(
          child: ChordReviewScreen(
            preview: ChordPreview(
              uuid: 'preview-1',
              chordName: 'Teste',
              artist: 'Artista',
              chordPro: '[C]Linha',
              status: 'REVIEW',
            ),
          ),
        ),
      ),
    );

    final statusTop = tester.getTopLeft(find.text('REVIEW')).dy;
    final noteTop = tester
        .getTopLeft(
          find.text('Revise acordes, secoes e tablaturas antes de salvar.'),
        )
        .dy;

    expect(noteTop, greaterThan(statusTop + 20));
  });

  testWidgets('chord player follows light theme outside performance mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const ChordPlayerScreen(
          chord: ChordDetail(
            uuid: '1',
            chordName: 'Teste',
            artist: 'Artista',
            chordPro: '[C]Linha',
            addBy: 'tester',
          ),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppThemeColors.light.ink);
  });
}
