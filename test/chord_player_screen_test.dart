import 'package:chordbase/core/api_client.dart';
import 'package:chordbase/core/models.dart';
import 'package:chordbase/core/token_store.dart';
import 'package:chordbase/features/chords/chords_repository.dart';
import 'package:chordbase/features/chords/chords_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders cue lines as musical callouts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChordPlayerScreen(
          chord: ChordDetail(
            uuid: '1',
            chordName: 'Billie Jean',
            artist: 'Michael Jackson',
            chordPro: 'F#m (Frase 1)\nBillie Jean is not my lover',
            addBy: 'tester',
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'F#m (Frase 1)',
      ),
      findsOneWidget,
    );
    expect(find.text('Billie Jean is not my lover'), findsOneWidget);
  });

  testWidgets('uses cue indentation above the following lyric', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChordPlayerScreen(
          chord: ChordDetail(
            uuid: '1',
            chordName: 'Billie Jean',
            artist: 'Michael Jackson',
            chordPro: '        Bm (Frase 2)\nWho claims that I am the one',
            addBy: 'tester',
          ),
        ),
      ),
    );

    final cueFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText() == 'Bm (Frase 2)',
    );
    final lyricFinder = find.text('Who claims that I am the one');

    expect(cueFinder, findsOneWidget);
    expect(lyricFinder, findsOneWidget);
    expect(
      tester.getTopLeft(cueFinder).dx,
      greaterThan(tester.getTopLeft(lyricFinder).dx),
    );
  });

  testWidgets('groups tablature parts into tab block views', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChordPlayerScreen(
          chord: ChordDetail(
            uuid: '1',
            chordName: 'Samurai',
            artist: 'Djavan',
            chordPro: '''
Parte 1 de 2
[E7M] [Gº] [G#m7] [C#7(9)]
E|---4-----x-4----------------|
B|---4-----x-4-2--------------|
Parte 2 de 2
[E7M] [Gº] [G#m7] [B7(9)]
E|---4-----x-4----------------|
B|---4-----x-4-2--------------|
''',
            addBy: 'tester',
          ),
        ),
      ),
    );

    expect(find.byType(TabBlockView), findsNWidgets(2));
    expect(find.text('E7M Gº G#m7 C#7(9)'), findsOneWidget);
    expect(find.text('E7M Gº G#m7 B7(9)'), findsOneWidget);
  });

  testWidgets('shows a session expired state for unauthorized chord loads', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordsRepositoryProvider.overrideWithValue(
            _UnauthorizedChordsRepository(),
          ),
        ],
        child: const MaterialApp(home: ChordPlayerLoader(uuid: 'chord-uuid')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sessao expirada'), findsOneWidget);
    expect(find.text('Entre novamente para abrir esta cifra.'), findsOneWidget);
    expect(find.text('Nao foi possivel abrir'), findsNothing);
  });
}

class _UnauthorizedChordsRepository extends ChordsRepository {
  _UnauthorizedChordsRepository() : super(_UnusedApiClient());

  @override
  Future<ChordDetail> getById(String uuid) {
    throw const ApiException('Unauthorized', statusCode: 401);
  }
}

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient()
    : super(const TokenStore(FlutterSecureStorage()), onSessionExpired: () {});
}
