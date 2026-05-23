import 'package:chordbase/core/api_client.dart';
import 'package:chordbase/core/models.dart';
import 'package:chordbase/core/theme.dart';
import 'package:chordbase/core/token_store.dart';
import 'package:chordbase/features/chords/chords_repository.dart';
import 'package:chordbase/features/chords/chords_screen.dart';
import 'package:chordbase/features/setlists/setlists_repository.dart';
import 'package:chordbase/features/setlists/setlists_screen.dart';
import 'package:chordbase/features/shell/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('home metric cards open their target actions', (tester) async {
    var chordsOpened = false;
    var setlistsOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordsRepositoryProvider.overrideWithValue(_FakeChordsRepository()),
          setlistsRepositoryProvider.overrideWithValue(
            _FakeSetlistsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: HomeScreen(
            user: _user,
            onImportChord: () {},
            onCreateSetlist: () {},
            onOpenChords: () => chordsOpened = true,
            onOpenSetlists: () => setlistsOpened = true,
            onReviewChords: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-metric-chords')));
    await tester.tap(find.byKey(const ValueKey('home-metric-setlists')));
    expect(chordsOpened, isTrue);
    expect(setlistsOpened, isTrue);

    await tester.tap(find.byKey(const ValueKey('home-metric-invites')));
    await tester.pumpAndSettle();
    expect(
      find.text('Convites e cifras que precisam de revisao.'),
      findsOneWidget,
    );
  });

  testWidgets('chords screen identifies personal and global libraries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordsRepositoryProvider.overrideWithValue(_FakeChordsRepository()),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ChordsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suas cifras'), findsOneWidget);
    expect(find.text('Buscar cifras publicadas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'vento');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Cifras publicadas encontradas'), findsOneWidget);
    expect(find.text('Revisar'), findsNothing);
  });

  testWidgets('empty setlist offers published selection and new import', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chordsRepositoryProvider.overrideWithValue(_FakeChordsRepository()),
          setlistsRepositoryProvider.overrideWithValue(
            _FakeSetlistsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SetlistDetailScreen(setlist: _emptySetlist),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua setlist esta vazia'), findsOneWidget);
    await tester.tap(find.text('Adicionar cifra').last);
    await tester.pumpAndSettle();

    expect(find.text('Importar nova cifra'), findsOneWidget);
    expect(find.text('Suas cifras publicadas'), findsOneWidget);
    expect(find.text('Cifra publicada'), findsOneWidget);
    expect(find.text('Cifra em revisao'), findsNothing);
  });
}

const _user = UserProfile(
  uuid: 'user-1',
  userName: 'gabriel',
  email: 'gabriel@example.com',
  roles: ['ROLE_USER'],
);

const _emptySetlist = Setlist(
  uuid: 'setlist-1',
  name: 'Ensaio',
  visibility: 'PRIVATE',
  ownerUuid: 'user-1',
  ownerUserName: 'gabriel',
  chords: [],
  collaborators: [],
);

class _FakeChordsRepository extends ChordsRepository {
  _FakeChordsRepository() : super(_UnusedApiClient());

  @override
  Future<List<ChordSummary>> mine() async => const [
    ChordSummary(
      uuid: 'published',
      chordName: 'Cifra publicada',
      artist: 'Artista',
      addBy: 'gabriel',
      status: 'PUBLISHED',
    ),
    ChordSummary(
      uuid: 'review',
      chordName: 'Cifra em revisao',
      artist: 'Artista',
      addBy: 'gabriel',
      status: 'REVIEW',
    ),
  ];

  @override
  Future<List<ChordSummary>> search(String query) async => const [
    ChordSummary(
      uuid: 'other',
      chordName: 'Vento',
      artist: 'Outro artista',
      addBy: 'outro-user',
      status: 'PUBLISHED',
    ),
  ];
}

class _FakeSetlistsRepository extends SetlistsRepository {
  _FakeSetlistsRepository() : super(_UnusedApiClient());

  @override
  Future<List<Setlist>> mine() async => const [];

  @override
  Future<List<SetlistInvite>> invites() async => const [];
}

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient()
    : super(const TokenStore(FlutterSecureStorage()), onSessionExpired: () {});
}
