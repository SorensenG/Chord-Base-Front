import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/scheduler.dart';

import '../../core/models.dart';
import '../../core/api_client.dart';
import '../../core/recent_activity_store.dart';
import '../../core/theme.dart';
import '../../core/user_messages.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/empty_state.dart';
import '../auth/auth_repository.dart';
import 'chordpro_parser.dart';
import 'chords_repository.dart';

final chordLibraryFilterProvider = StateProvider<ChordLibraryFilter>((ref) {
  return ChordLibraryFilter.all;
});

enum ChordLibraryFilter {
  all('Todas'),
  published('Publicadas'),
  review('Revisar');

  const ChordLibraryFilter(this.label);

  final String label;
}

Future<String?> runChordImportFlow(
  BuildContext context,
  WidgetRef ref, {
  String? refreshSearchQuery,
}) async {
  final file = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: [
      'pdf',
      'txt',
      'png',
      'jpg',
      'jpeg',
      'webp',
      'heic',
      'heif',
    ],
  );
  if (file == null || file.files.isEmpty || !context.mounted) return null;

  final selectedFile = file.files.single;
  if (isChordUploadTooLarge(selectedFile)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(chordUploadTooLargeMessage)));
    return null;
  }

  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final preview = await ref
        .read(chordsRepositoryProvider)
        .preview(selectedFile);
    if (!context.mounted) return null;
    if (dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }

    final uuid = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ChordReviewScreen(preview: preview)),
    );
    if (uuid == null || !context.mounted) return uuid;

    ref.invalidate(myChordsProvider);
    final query = refreshSearchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      ref.invalidate(chordSearchProvider(query));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cifra adicionada.'),
        action: SnackBarAction(
          label: 'Abrir',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChordPlayerLoader(uuid: uuid)),
            );
          },
        ),
      ),
    );
    return uuid;
  } catch (error) {
    if (!context.mounted) return null;
    if (dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    return null;
  }
}

class ChordsScreen extends ConsumerStatefulWidget {
  const ChordsScreen({super.key});

  @override
  ConsumerState<ChordsScreen> createState() => _ChordsScreenState();
}

class _ChordsScreenState extends ConsumerState<ChordsScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim();
    final filter = ref.watch(chordLibraryFilterProvider);
    final myChords = ref.watch(myChordsProvider);
    final result = ref.watch(chordSearchProvider(normalizedQuery));
    final isAdmin =
        ref.watch(authControllerProvider).whenOrNull(data: (u) => u?.isAdmin) ??
        false;
    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeader(
            title: 'Cifras',
            subtitle: 'Importe, revise e encontre musicas para tocar.',
            actions: [
              FilledButton.icon(
                onPressed: _upload,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Importar'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              labelText: 'Buscar cifra',
              hintText: 'Nome da musica',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _query = _search.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ActionToolbar(
            children: [
              for (final filter in ChordLibraryFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: ref.watch(chordLibraryFilterProvider) == filter,
                  onSelected: (_) =>
                      ref.read(chordLibraryFilterProvider.notifier).state =
                          filter,
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (normalizedQuery.isEmpty)
            myChords.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Nao foi possivel carregar suas cifras',
                message: userMessage(error),
              ),
              data: (items) {
                final filtered = _applyFilter(items, filter);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.music_note_rounded,
                    title: 'Nenhuma cifra nesse filtro',
                    message:
                        'Importe uma cifra ou altere os filtros para continuar.',
                  );
                }
                return _ChordSummaryList(
                  title: 'Minha biblioteca',
                  subtitle: '${filtered.length} cifra(s) encontradas',
                  items: filtered,
                  onOpen: _openChord,
                  onEdit: _editChord,
                  onDelete: _deleteChord,
                  isAdmin: isAdmin,
                );
              },
            )
          else
            result.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nao foi possivel buscar',
                message: userMessage(error),
              ),
              data: (items) {
                final filtered = _applyFilter(items, filter);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nada encontrado',
                    message: 'Tente outro nome ou envie a cifra.',
                  );
                }
                return _ChordSummaryList(
                  title: 'Resultado da busca',
                  subtitle: '${filtered.length} resultado(s)',
                  items: filtered,
                  onOpen: _openChord,
                  onEdit: isAdmin ? _editChord : null,
                  onDelete: isAdmin ? _deleteChord : null,
                  isAdmin: isAdmin,
                );
              },
            ),
        ],
      ),
    );
  }

  List<ChordSummary> _applyFilter(
    List<ChordSummary> items,
    ChordLibraryFilter filter,
  ) {
    return switch (filter) {
      ChordLibraryFilter.all => items,
      ChordLibraryFilter.published =>
        items.where((item) => item.status == 'PUBLISHED').toList(),
      ChordLibraryFilter.review =>
        items.where((item) => item.status != 'PUBLISHED').toList(),
    };
  }

  Future<void> _upload() async {
    await runChordImportFlow(context, ref, refreshSearchQuery: _query);
  }

  Future<void> _openChord(String uuid) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChordPlayerLoader(uuid: uuid)));
  }

  Future<void> _editChord(ChordSummary chord) async {
    try {
      final detail = await ref
          .read(chordsRepositoryProvider)
          .getById(chord.uuid);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChordEditScreen(chord: detail)));
      ref.invalidate(myChordsProvider);
      if (_query.trim().isNotEmpty) {
        ref.invalidate(chordSearchProvider(_query.trim()));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }

  Future<void> _deleteChord(ChordSummary chord) async {
    try {
      await ref.read(chordsRepositoryProvider).delete(chord.uuid);
      ref.invalidate(myChordsProvider);
      if (_query.trim().isNotEmpty) {
        ref.invalidate(chordSearchProvider(_query.trim()));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }
}

class _ChordSummaryList extends StatelessWidget {
  const _ChordSummaryList({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onOpen,
    required this.isAdmin,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<ChordSummary> items;
  final ValueChanged<String> onOpen;
  final bool isAdmin;
  final ValueChanged<ChordSummary>? onEdit;
  final ValueChanged<ChordSummary>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        for (final chord in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SongListRow(
              chord: chord,
              onOpen: () => onOpen(chord.uuid),
              onEdit: (!chord.isPublished || isAdmin) && onEdit != null
                  ? () => onEdit!(chord)
                  : null,
              onDelete: (!chord.isPublished || isAdmin) && onDelete != null
                  ? () async {
                      final confirmed = await _confirmDelete(
                        context,
                        chord.chordName,
                      );
                      if (confirmed) onDelete!(chord);
                    }
                  : null,
            ),
          ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir cifra'),
            content: Text('Excluir "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class ChordEditScreen extends ConsumerStatefulWidget {
  const ChordEditScreen({super.key, required this.chord});

  final ChordDetail chord;

  @override
  ConsumerState<ChordEditScreen> createState() => _ChordEditScreenState();
}

class _ChordEditScreenState extends ConsumerState<ChordEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _artist;
  late final TextEditingController _chordPro;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.chord.chordName);
    _artist = TextEditingController(text: widget.chord.artist);
    _chordPro = TextEditingController(text: widget.chord.chordPro);
    _name.addListener(_refreshPreview);
    _artist.addListener(_refreshPreview);
    _chordPro.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _name.removeListener(_refreshPreview);
    _artist.removeListener(_refreshPreview);
    _chordPro.removeListener(_refreshPreview);
    _name.dispose();
    _artist.dispose();
    _chordPro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ImportReviewLayout(
      title: 'Editar cifra',
      subtitle: 'Ajuste metadados e confira o resultado renderizado.',
      details: Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Musica'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _artist,
            decoration: const InputDecoration(labelText: 'Artista'),
          ),
        ],
      ),
      editor: TextField(
        controller: _chordPro,
        minLines: 18,
        maxLines: 28,
        style: const TextStyle(fontFamily: 'Roboto Mono'),
        decoration: const InputDecoration(labelText: 'ChordPro'),
      ),
      preview: _ChordPreviewPane(
        chordName: _name.text,
        artist: _artist.text,
        chordPro: _chordPro.text,
      ),
      actions: [
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Salvar'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChordPlayerScreen(
                  chord: ChordDetail(
                    uuid: widget.chord.uuid,
                    chordName: _name.text,
                    artist: _artist.text,
                    chordPro: _chordPro.text,
                    addBy: widget.chord.addBy,
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Ver modo reproducao'),
        ),
      ],
    );
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    try {
      await ref
          .read(chordsRepositoryProvider)
          .update(
            uuid: widget.chord.uuid,
            chordName: _name.text.trim(),
            artist: _artist.text.trim(),
            chordPro: _chordPro.text,
          );
      ref.invalidate(myChordsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }
}

class ChordReviewScreen extends ConsumerStatefulWidget {
  const ChordReviewScreen({super.key, required this.preview});

  final ChordPreview preview;

  @override
  ConsumerState<ChordReviewScreen> createState() => _ChordReviewScreenState();
}

class _ChordReviewScreenState extends ConsumerState<ChordReviewScreen> {
  late final TextEditingController _name;
  late final TextEditingController _artist;
  late final TextEditingController _chordPro;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.preview.chordName);
    _artist = TextEditingController(text: widget.preview.artist);
    _chordPro = TextEditingController(text: widget.preview.chordPro);
    _name.addListener(_refreshPreview);
    _artist.addListener(_refreshPreview);
    _chordPro.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _name.removeListener(_refreshPreview);
    _artist.removeListener(_refreshPreview);
    _chordPro.removeListener(_refreshPreview);
    _name.dispose();
    _artist.dispose();
    _chordPro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ImportReviewLayout(
      title: 'Revisar cifra',
      subtitle: 'Confira o ChordPro extraido antes de publicar.',
      details: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final note = Text(
                'Revise acordes, secoes e tablaturas antes de salvar.',
                style: TextStyle(color: colors.muted),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(label: widget.preview.status),
                    const SizedBox(height: 8),
                    note,
                  ],
                );
              }
              return Row(
                children: [
                  StatusBadge(label: widget.preview.status),
                  const SizedBox(width: 10),
                  Expanded(child: note),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Musica'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _artist,
            decoration: const InputDecoration(labelText: 'Artista'),
          ),
        ],
      ),
      editor: TextField(
        controller: _chordPro,
        minLines: 18,
        maxLines: 28,
        style: const TextStyle(fontFamily: 'Roboto Mono'),
        decoration: const InputDecoration(labelText: 'ChordPro'),
      ),
      preview: _ChordPreviewPane(
        chordName: _name.text,
        artist: _artist.text,
        chordPro: _chordPro.text,
      ),
      actions: [
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Publicar cifra'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChordPlayerScreen(
                  chord: ChordDetail(
                    uuid: widget.preview.uuid,
                    chordName: _name.text,
                    artist: _artist.text,
                    chordPro: _chordPro.text,
                    addBy: '',
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Ver modo reproducao'),
        ),
      ],
    );
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    try {
      final uuid = await ref
          .read(chordsRepositoryProvider)
          .confirm(
            uuid: widget.preview.uuid,
            chordName: _name.text.trim(),
            artist: _artist.text.trim(),
            chordPro: _chordPro.text,
          );
      if (!mounted) return;
      ref.invalidate(myChordsProvider);
      ref.invalidate(chordSearchProvider(_name.text.trim()));
      Navigator.of(context).pop(uuid);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }
}

class _ChordPreviewPane extends StatelessWidget {
  const _ChordPreviewPane({
    required this.chordName,
    required this.artist,
    required this.chordPro,
  });

  final String chordName;
  final String artist;
  final String chordPro;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final document = ChordProDocument.parse(chordPro);
    final playerItems = _PlayerItem.fromLines(document.lines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chordName.isEmpty ? 'Sem titulo' : chordName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          artist.isEmpty ? 'Artista nao informado' : artist,
          style: TextStyle(color: colors.muted),
        ),
        const Divider(height: 24),
        for (final item in playerItems.take(80))
          if (item.tabBlock != null)
            TabBlockView(
              lines: item.tabBlock!,
              fontSize: 13,
              performance: false,
            )
          else if (item.cueLine != null && item.lyricLine != null)
            CueLyricLineView(
              cueLine: item.cueLine!,
              lyricLine: item.lyricLine!,
              fontSize: 13,
              performance: false,
            )
          else
            ChordLineView(line: item.line!, fontSize: 13, performance: false),
        if (playerItems.length > 80)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Preview reduzido. Abra o modo reproducao para ver tudo.',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class ChordPlayerLoader extends ConsumerStatefulWidget {
  const ChordPlayerLoader({super.key, required this.uuid});

  final String uuid;

  @override
  ConsumerState<ChordPlayerLoader> createState() => _ChordPlayerLoaderState();
}

class _ChordPlayerLoaderState extends ConsumerState<ChordPlayerLoader> {
  String? _recordedUuid;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_chordDetailProvider(widget.uuid));
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: _isUnauthorized(error)
              ? Icons.lock_outline_rounded
              : Icons.error_outline_rounded,
          title: _isUnauthorized(error)
              ? 'Sessao expirada'
              : 'Nao foi possivel abrir',
          message: _isUnauthorized(error)
              ? 'Entre novamente para abrir esta cifra.'
              : userMessage(error),
        ),
      ),
      data: (chord) {
        _recordRecentChord(chord);
        return ChordPlayerScreen(chord: chord);
      },
    );
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  void _recordRecentChord(ChordDetail chord) {
    if (_recordedUuid == chord.uuid) return;
    _recordedUuid = chord.uuid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(recentActivityStoreProvider)
          .save(
            RecentActivity(
              type: RecentActivityType.chord,
              uuid: chord.uuid,
              title: chord.chordName,
              subtitle: chord.artist,
            ),
          );
      ref.invalidate(recentActivityProvider);
    });
  }
}

final _chordDetailProvider = FutureProvider.autoDispose
    .family<ChordDetail, String>((ref, uuid) {
      return ref.watch(chordsRepositoryProvider).getById(uuid);
    });

class ChordPlayerScreen extends StatefulWidget {
  const ChordPlayerScreen({super.key, required this.chord, this.bottomBar});

  final ChordDetail chord;
  final Widget? bottomBar;

  @override
  State<ChordPlayerScreen> createState() => _ChordPlayerScreenState();
}

class _ChordPlayerScreenState extends State<ChordPlayerScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _autoScrollTicker;
  Duration? _lastAutoScrollTick;
  var _transpose = 0;
  var _fontSize = 18.0;
  var _performance = false;
  var _autoScroll = false;
  var _autoScrollSpeed = 0.4;
  var _showChords = false;

  @override
  void initState() {
    super.initState();
    _autoScrollTicker = createTicker(_handleAutoScrollTick);
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final document = ChordProDocument.parse(
      widget.chord.chordPro,
    ).transpose(_transpose);
    final playerItems = _PlayerItem.fromLines(document.lines);
    return Scaffold(
      backgroundColor: _performance ? Colors.black : colors.ink,
      appBar: _performance
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chord.chordName),
                  Text(
                    widget.chord.artist,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Modo palco',
                  onPressed: () => setState(() => _performance = true),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
      body: Column(
        children: [
          PlayerToolbar(
            transpose: _transpose,
            fontSize: _fontSize,
            autoScroll: _autoScroll,
            autoScrollSpeed: _autoScrollSpeed,
            performance: _performance,
            showChords: _showChords,
            onTranspose: (value) => setState(() => _transpose += value),
            onFont: (value) =>
                setState(() => _fontSize = (_fontSize + value).clamp(14, 30)),
            onAutoScroll: _toggleAutoScroll,
            onAutoScrollSpeed: (value) =>
                setState(() => _autoScrollSpeed = value),
            onExitPerformance: () => setState(() => _performance = false),
            onToggleChords: () => setState(() => _showChords = !_showChords),
          ),
          if (_showChords && document.chords.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) =>
                    Chip(label: Text(document.chords[index])),
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: document.chords.length,
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _performance ? double.infinity : 1040,
                ),
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    _performance ? 28 : 22,
                    18,
                    _performance ? 28 : 22,
                    70,
                  ),
                  itemCount: playerItems.length,
                  itemBuilder: (_, index) {
                    final item = playerItems[index];
                    if (item.tabBlock != null) {
                      return TabBlockView(
                        lines: item.tabBlock!,
                        fontSize: _fontSize,
                        performance: _performance,
                      );
                    }
                    if (item.cueLine != null && item.lyricLine != null) {
                      return CueLyricLineView(
                        cueLine: item.cueLine!,
                        lyricLine: item.lyricLine!,
                        fontSize: _fontSize,
                        performance: _performance,
                      );
                    }
                    return ChordLineView(
                      line: item.line!,
                      fontSize: _fontSize,
                      performance: _performance,
                    );
                  },
                ),
              ),
            ),
          ),
          if (widget.bottomBar != null) widget.bottomBar!,
        ],
      ),
    );
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    _lastAutoScrollTick = null;
    if (_autoScroll) {
      _autoScrollTicker.start();
    } else {
      _autoScrollTicker.stop();
    }
  }

  void _handleAutoScrollTick(Duration elapsed) {
    if (!_autoScroll || !_scroll.hasClients) return;
    final previous = _lastAutoScrollTick;
    _lastAutoScrollTick = elapsed;
    if (previous == null) return;

    final seconds = (elapsed - previous).inMicroseconds / 1000000;
    if (seconds <= 0) return;

    final pixelsPerSecond =
        _autoScrollSpeed.clamp(0.1, 1.0).toDouble() * _lineExtent;
    final maxExtent = _scroll.position.maxScrollExtent;
    final next = (_scroll.offset + pixelsPerSecond * seconds).clamp(
      0.0,
      maxExtent,
    );
    _scroll.jumpTo(next.toDouble());
    if (next >= maxExtent) {
      _autoScrollTicker.stop();
      if (mounted) setState(() => _autoScroll = false);
    }
  }

  double get _lineExtent => _fontSize * 1.35 + 10;
}

class PlayerToolbar extends StatelessWidget {
  const PlayerToolbar({
    super.key,
    required this.transpose,
    required this.fontSize,
    required this.autoScroll,
    required this.autoScrollSpeed,
    required this.performance,
    required this.showChords,
    required this.onTranspose,
    required this.onFont,
    required this.onAutoScroll,
    required this.onAutoScrollSpeed,
    required this.onExitPerformance,
    required this.onToggleChords,
  });

  final int transpose;
  final double fontSize;
  final bool autoScroll;
  final double autoScrollSpeed;
  final bool performance;
  final bool showChords;
  final ValueChanged<int> onTranspose;
  final ValueChanged<double> onFont;
  final VoidCallback onAutoScroll;
  final ValueChanged<double> onAutoScrollSpeed;
  final VoidCallback onExitPerformance;
  final VoidCallback onToggleChords;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    if (compact) return _buildCompact(context);
    return _buildWide(context);
  }

  Widget _buildWide(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: performance ? Colors.black : colors.surface,
          border: Border(
            bottom: BorderSide(
              color: performance ? AppColors.line : colors.line,
            ),
          ),
        ),
        child: IconTheme(
          data: IconThemeData(color: performance ? Colors.white : colors.text),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                _ToolbarGroup(
                  performance: performance,
                  children: [
                    IconButton(
                      tooltip: 'Diminuir tom',
                      onPressed: () => onTranspose(-1),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text(
                      'Tom ${transpose >= 0 ? '+$transpose' : transpose}',
                      style: TextStyle(
                        color: performance ? Colors.white : colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aumentar tom',
                      onPressed: () => onTranspose(1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                _ToolbarGroup(
                  performance: performance,
                  children: [
                    IconButton(
                      tooltip: 'Diminuir texto',
                      onPressed: () => onFont(-1),
                      icon: const Icon(Icons.text_decrease_rounded),
                    ),
                    Text(
                      '${fontSize.round()}',
                      style: TextStyle(
                        color: performance ? AppColors.muted : colors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aumentar texto',
                      onPressed: () => onFont(1),
                      icon: const Icon(Icons.text_increase_rounded),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                _ToolbarGroup(
                  performance: performance,
                  children: [
                    IconButton(
                      tooltip: 'Lista de acordes',
                      onPressed: onToggleChords,
                      color: showChords
                          ? AppColors.teal
                          : performance
                          ? Colors.white
                          : null,
                      icon: const Icon(Icons.piano_rounded),
                    ),
                    IconButton(
                      tooltip: 'Auto rolagem',
                      onPressed: onAutoScroll,
                      color: autoScroll
                          ? AppColors.teal
                          : performance
                          ? Colors.white
                          : null,
                      icon: const Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 214,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              _speedLabel(autoScrollSpeed),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: performance ? Colors.white : colors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              value: autoScrollSpeed.clamp(0.1, 1.0).toDouble(),
                              label: _speedLabel(autoScrollSpeed),
                              onChanged: onAutoScrollSpeed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (performance) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'Sair do modo palco',
                    onPressed: onExitPerformance,
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final colors = context.appColors;
    final speed = autoScrollSpeed.clamp(0.1, 1.0).toDouble();
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: performance ? Colors.black : colors.surface,
          border: Border(
            bottom: BorderSide(
              color: performance ? AppColors.line : colors.line,
            ),
          ),
        ),
        child: IconTheme(
          data: IconThemeData(color: performance ? Colors.white : colors.text),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CompactToolbarGroup(
                      performance: performance,
                      children: [
                        _compactIconButton(
                          tooltip: 'Diminuir tom',
                          onPressed: () => onTranspose(-1),
                          icon: Icons.remove_rounded,
                        ),
                        SizedBox(
                          width: 76,
                          child: Text(
                            'Tom ${transpose >= 0 ? '+$transpose' : transpose}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: performance ? Colors.white : colors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _compactIconButton(
                          tooltip: 'Aumentar tom',
                          onPressed: () => onTranspose(1),
                          icon: Icons.add_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CompactToolbarGroup(
                    performance: performance,
                    children: [
                      _compactIconButton(
                        tooltip: 'Diminuir texto',
                        onPressed: () => onFont(-1),
                        icon: Icons.text_decrease_rounded,
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${fontSize.round()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: performance ? AppColors.muted : colors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _compactIconButton(
                        tooltip: 'Aumentar texto',
                        onPressed: () => onFont(1),
                        icon: Icons.text_increase_rounded,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CompactToolbarGroup(
                    performance: performance,
                    children: [
                      _compactIconButton(
                        tooltip: 'Lista de acordes',
                        onPressed: onToggleChords,
                        color: showChords
                            ? AppColors.teal
                            : performance
                            ? Colors.white
                            : null,
                        icon: Icons.piano_rounded,
                      ),
                      _compactIconButton(
                        tooltip: 'Auto rolagem',
                        onPressed: onAutoScroll,
                        color: autoScroll
                            ? AppColors.teal
                            : performance
                            ? Colors.white
                            : null,
                        icon: Icons.keyboard_double_arrow_down_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        color: performance
                            ? AppColors.surface
                            : colors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: performance ? AppColors.line : colors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              _speedLabel(speed),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: performance ? Colors.white : colors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              value: speed,
                              label: _speedLabel(speed),
                              onChanged: onAutoScrollSpeed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (performance) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton.filledTonal(
                        tooltip: 'Sair do modo palco',
                        onPressed: onExitPerformance,
                        icon: const Icon(Icons.fullscreen_exit_rounded),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactIconButton({
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: color,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: Icon(icon),
    );
  }

  String _speedLabel(double value) {
    final normalized = value.clamp(0.1, 1.0).toDouble();
    return '${normalized.toStringAsFixed(1)} linha/s';
  }
}

class _CompactToolbarGroup extends StatelessWidget {
  const _CompactToolbarGroup({
    required this.children,
    required this.performance,
  });

  final List<Widget> children;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: performance ? AppColors.surface : colors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: performance ? AppColors.line : colors.line),
      ),
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.children, required this.performance});

  final List<Widget> children;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: performance ? AppColors.surface : colors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: performance ? AppColors.line : colors.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PlayerItem {
  const _PlayerItem.line(this.line)
    : tabBlock = null,
      cueLine = null,
      lyricLine = null;
  const _PlayerItem.tabBlock(this.tabBlock)
    : line = null,
      cueLine = null,
      lyricLine = null;
  const _PlayerItem.cueLyric(this.cueLine, this.lyricLine)
    : line = null,
      tabBlock = null;

  final ChordProLine? line;
  final List<ChordProLine>? tabBlock;
  final ChordProLine? cueLine;
  final ChordProLine? lyricLine;

  static List<_PlayerItem> fromLines(List<ChordProLine> lines) {
    final items = <_PlayerItem>[];
    var index = 0;

    while (index < lines.length) {
      if (_startsTabBlock(lines, index)) {
        final block = <ChordProLine>[];

        if (_isTabPartHeader(lines[index])) {
          block.add(lines[index]);
          index++;
        }

        if (index < lines.length &&
            lines[index].type == ChordLineType.chordOnly) {
          block.add(lines[index]);
          index++;
        }

        while (index < lines.length &&
            lines[index].type == ChordLineType.tablature) {
          block.add(lines[index]);
          index++;
        }

        items.add(_PlayerItem.tabBlock(block));
        continue;
      }

      if (_startsCueLyricBlock(lines, index)) {
        items.add(_PlayerItem.cueLyric(lines[index], lines[index + 1]));
        index += 2;
        continue;
      }

      items.add(_PlayerItem.line(lines[index]));
      index++;
    }

    return items;
  }

  static bool _startsTabBlock(List<ChordProLine> lines, int index) {
    final line = lines[index];
    if (line.type == ChordLineType.tablature) return true;

    if (line.type == ChordLineType.chordOnly) {
      return index + 1 < lines.length &&
          lines[index + 1].type == ChordLineType.tablature;
    }

    if (!_isTabPartHeader(line)) return false;
    var next = index + 1;
    if (next < lines.length && lines[next].type == ChordLineType.chordOnly) {
      next++;
    }
    return next < lines.length && lines[next].type == ChordLineType.tablature;
  }

  static bool _startsCueLyricBlock(List<ChordProLine> lines, int index) {
    if (lines[index].type != ChordLineType.cue) return false;
    if (index + 1 >= lines.length) return false;

    final nextLine = lines[index + 1];
    return nextLine.type == ChordLineType.lyrics &&
        nextLine.chordPlacements.isEmpty;
  }

  static bool _isTabPartHeader(ChordProLine line) {
    return line.type == ChordLineType.lyrics &&
        RegExp(
          r'^\s*Parte\s+\d+\s+de\s+\d+',
          caseSensitive: false,
        ).hasMatch(line.lyrics);
  }
}

class CueLyricLineView extends StatelessWidget {
  const CueLyricLineView({
    super.key,
    required this.cueLine,
    required this.lyricLine,
    required this.fontSize,
    required this.performance,
  });

  final ChordProLine cueLine;
  final ChordProLine lyricLine;
  final double fontSize;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lyricStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.18,
      color: performance ? Colors.white : colors.text,
    );
    final cueStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.05,
      color: performance ? Colors.white : colors.text,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _MeasuredCueLyricLine(
          cueLine: cueLine,
          lyricLine: lyricLine,
          lyricStyle: lyricStyle,
          cueStyle: cueStyle,
          performance: performance,
        ),
      ),
    );
  }
}

class _MeasuredCueLyricLine extends StatelessWidget {
  const _MeasuredCueLyricLine({
    required this.cueLine,
    required this.lyricLine,
    required this.lyricStyle,
    required this.cueStyle,
    required this.performance,
  });

  final ChordProLine cueLine;
  final ChordProLine lyricLine;
  final TextStyle lyricStyle;
  final TextStyle cueStyle;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final lyricSize = _measureText(
      lyricLine.lyrics,
      lyricStyle,
      direction,
      textScaler,
    );
    final prefix = lyricLine.lyrics.substring(
      0,
      cueLine.cueIndent.clamp(0, lyricLine.lyrics.length),
    );
    final cueLeft = _measureText(
      prefix,
      lyricStyle,
      direction,
      textScaler,
    ).width;
    final cueSize = _measureText(
      _cuePlainText(cueLine),
      cueStyle,
      direction,
      textScaler,
    );
    final lyricTop = cueSize.height;
    final width = math.max(lyricSize.width, cueLeft + cueSize.width);

    return SizedBox(
      width: width,
      height: lyricTop + lyricSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: cueLeft,
            top: 0,
            child: _CueRichText(
              line: cueLine,
              fontSize: cueStyle.fontSize,
              performance: performance,
            ),
          ),
          Positioned(
            left: 0,
            top: lyricTop,
            child: Text(lyricLine.lyrics, softWrap: false, style: lyricStyle),
          ),
        ],
      ),
    );
  }

  String _cuePlainText(ChordProLine line) {
    final buffer = StringBuffer();
    if (line.cueChord != null) buffer.write(line.cueChord);
    if (line.cueChord != null && line.cueLabel != null) buffer.write(' ');
    if (line.cueLabel != null) buffer.write(line.cueLabel);
    return buffer.toString();
  }

  Size _measureText(
    String text,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      maxLines: 1,
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.size;
  }
}

class ChordLineView extends StatelessWidget {
  const ChordLineView({
    super.key,
    required this.line,
    required this.fontSize,
    required this.performance,
  });

  final ChordProLine line;
  final double fontSize;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (line.type == ChordLineType.empty) return const SizedBox(height: 14);
    if (line.type == ChordLineType.directive) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          line.directive ?? '',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: fontSize + 1,
          ),
        ),
      );
    }
    if (line.type == ChordLineType.cue) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _CueRichText(
            line: line,
            fontSize: fontSize,
            performance: performance,
          ),
        ),
      );
    }
    if (line.type == ChordLineType.tablature) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            line.lyrics,
            softWrap: false,
            style: TextStyle(
              fontFamily: _tabFontFamily,
              fontFamilyFallback: _monoFontFallback,
              fontSize: fontSize,
              letterSpacing: 0,
              height: 1.2,
              color: performance ? Colors.white : colors.text,
            ),
          ),
        ),
      );
    }

    final lyricStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: line.chordPlacements.isEmpty ? 1.35 : 1.18,
      color: performance ? Colors.white : colors.text,
    );
    final chordStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.05,
      color: AppColors.teal,
      fontWeight: FontWeight.w900,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _MeasuredChordLine(
          line: line,
          lyricStyle: lyricStyle,
          chordStyle: chordStyle,
        ),
      ),
    );
  }
}

class _CueRichText extends StatelessWidget {
  const _CueRichText({
    required this.line,
    this.fontSize,
    required this.performance,
  });

  final ChordProLine line;
  final double? fontSize;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cueChord = line.cueChord;
    final cueLabel = line.cueLabel;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          letterSpacing: 0,
          color: performance ? Colors.white : colors.text,
        ),
        children: [
          if (cueChord != null)
            TextSpan(
              text: cueChord,
              style: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (cueChord != null && cueLabel != null) const TextSpan(text: ' '),
          if (cueLabel != null)
            TextSpan(
              text: cueLabel,
              style: TextStyle(
                color: performance ? AppColors.muted : colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class TabBlockView extends StatelessWidget {
  const TabBlockView({
    super.key,
    required this.lines,
    required this.fontSize,
    required this.performance,
  });

  final List<ChordProLine> lines;
  final double fontSize;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tabStyle = TextStyle(
      fontFamily: _tabFontFamily,
      fontFamilyFallback: _monoFontFallback,
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.18,
      color: performance ? Colors.white : colors.text,
    );
    final partStyle = tabStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: performance ? Colors.white : colors.text,
    );
    final chordStyle = tabStyle.copyWith(
      color: AppColors.teal,
      fontWeight: FontWeight.w900,
      height: 1.1,
    );

    final content = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            _TabBlockLine(
              line: line,
              tabStyle: tabStyle,
              partStyle: partStyle,
              chordStyle: chordStyle,
            ),
        ],
      ),
    );

    if (performance) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        child: content,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.line),
      ),
      child: content,
    );
  }
}

class _TabBlockLine extends StatelessWidget {
  const _TabBlockLine({
    required this.line,
    required this.tabStyle,
    required this.partStyle,
    required this.chordStyle,
  });

  final ChordProLine line;
  final TextStyle tabStyle;
  final TextStyle partStyle;
  final TextStyle chordStyle;

  @override
  Widget build(BuildContext context) {
    if (line.type == ChordLineType.chordOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 3),
        child: Text(
          _formatChordOnlyLine(line),
          softWrap: false,
          style: chordStyle,
        ),
      );
    }

    if (_PlayerItem._isTabPartHeader(line)) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(line.lyrics, softWrap: false, style: partStyle),
      );
    }

    return Text(line.lyrics, softWrap: false, style: tabStyle);
  }

  String _formatChordOnlyLine(ChordProLine line) {
    return line.raw.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]'),
      (match) => match.group(1)!.trim(),
    );
  }
}

class _MeasuredChordLine extends StatelessWidget {
  const _MeasuredChordLine({
    required this.line,
    required this.lyricStyle,
    required this.chordStyle,
  });

  final ChordProLine line;
  final TextStyle lyricStyle;
  final TextStyle chordStyle;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final lyricSize = _measureText(
      line.lyrics,
      lyricStyle,
      direction,
      textScaler,
    );

    if (line.chordPlacements.isEmpty) {
      return SizedBox(
        width: lyricSize.width,
        child: Text(line.lyrics, softWrap: false, style: lyricStyle),
      );
    }

    final chordSize = _measureText(
      'F#m7(11)',
      chordStyle,
      direction,
      textScaler,
    );
    final lyricTop = chordSize.height;
    final anchors = <_ChordAnchor>[];
    var width = lyricSize.width;
    var nextAvailableLeft = 0.0;

    for (final placement in line.chordPlacements) {
      final prefix = line.lyrics.substring(
        0,
        placement.position.clamp(0, line.lyrics.length),
      );
      final measuredLeft = _measureText(
        prefix,
        lyricStyle,
        direction,
        textScaler,
      ).width;
      final chordWidth = _measureText(
        placement.chord,
        chordStyle,
        direction,
        textScaler,
      ).width;
      final left = math.max(measuredLeft, nextAvailableLeft);
      anchors.add(_ChordAnchor(chord: placement.chord, left: left));
      nextAvailableLeft = left + chordWidth + 8;
      width = math.max(width, left + chordWidth);
    }

    final lyricHeight = line.lyrics.isEmpty ? 0.0 : lyricSize.height;
    final height = lyricTop + lyricHeight;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final anchor in anchors)
            Positioned(
              left: anchor.left,
              top: 0,
              child: Text(anchor.chord, softWrap: false, style: chordStyle),
            ),
          if (line.lyrics.isNotEmpty)
            Positioned(
              left: 0,
              top: lyricTop,
              child: Text(line.lyrics, softWrap: false, style: lyricStyle),
            ),
        ],
      ),
    );
  }

  Size _measureText(
    String text,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      maxLines: 1,
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.size;
  }
}

class _ChordAnchor {
  const _ChordAnchor({required this.chord, required this.left});

  final String chord;
  final double left;
}

const _tabFontFamily = 'Roboto Mono';
const _monoFontFallback = ['Courier New', 'Courier', 'monospace'];
