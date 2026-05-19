import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../auth/auth_repository.dart';
import 'chordpro_parser.dart';
import 'chords_repository.dart';

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
    final myChords = ref.watch(myChordsProvider);
    final result = ref.watch(chordSearchProvider(normalizedQuery));
    final isAdmin =
        ref.watch(authControllerProvider).whenOrNull(data: (u) => u?.isAdmin) ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cifras'),
        actions: [
          IconButton(
            tooltip: 'Enviar cifra',
            onPressed: _upload,
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
          const SizedBox(height: 18),
          AppCard(
            onTap: _upload,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.coral),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adicionar nova cifra',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PDF, imagem ou TXT para extrair ChordPro.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (normalizedQuery.isEmpty)
            myChords.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Nao foi possivel carregar suas cifras',
                message: error.toString(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.music_note_rounded,
                    title: 'Nenhuma cifra criada ainda',
                    message:
                        'Envie uma cifra para ela aparecer aqui e poder entrar em setlists.',
                  );
                }
                return _ChordSummaryList(
                  title: 'Minhas cifras',
                  items: items,
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
                message: error.toString(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nada encontrado',
                    message: 'Tente outro nome ou envie a cifra.',
                  );
                }
                return _ChordSummaryList(
                  title: 'Resultado da busca',
                  items: items,
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

  Future<void> _upload() async {
    final file = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg'],
    );
    if (file == null || file.files.isEmpty || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final preview = await ref
          .read(chordsRepositoryProvider)
          .preview(file.files.single);
      if (!mounted) return;
      Navigator.pop(context);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChordReviewScreen(preview: preview)),
      );
      ref.invalidate(myChordsProvider);
      if (_query.trim().isNotEmpty) {
        ref.invalidate(chordSearchProvider(_query.trim()));
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _ChordSummaryList extends StatelessWidget {
  const _ChordSummaryList({
    required this.title,
    required this.items,
    required this.onOpen,
    required this.isAdmin,
    this.onEdit,
    this.onDelete,
  });

  final String title;
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
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final chord in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('chord-${chord.uuid}-${chord.status}'),
              background: _SwipeBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.teal,
                icon: Icons.edit_rounded,
                label: 'Editar',
              ),
              secondaryBackground: _SwipeBackground(
                alignment: Alignment.centerRight,
                color: AppColors.coral,
                icon: Icons.delete_rounded,
                label: 'Excluir',
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  final canEdit = !chord.isPublished || isAdmin;
                  if (canEdit) onEdit?.call(chord);
                  return false;
                }
                final canDelete = !chord.isPublished || isAdmin;
                if (!canDelete || onDelete == null) return false;
                final confirmed = await _confirmDelete(
                  context,
                  chord.chordName,
                );
                if (confirmed) onDelete!(chord);
                return false;
              },
              child: AppCard(
                onTap: () => onOpen(chord.uuid),
                child: Row(
                  children: [
                    const Icon(
                      Icons.library_music_rounded,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chord.chordName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${chord.artist} - por ${chord.addBy}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(chord.status),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
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
  }

  @override
  void dispose() {
    _name.dispose();
    _artist.dispose();
    _chordPro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cifra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 12),
          TextField(
            controller: _chordPro,
            minLines: 14,
            maxLines: 24,
            style: const TextStyle(fontFamily: 'Roboto Mono'),
            decoration: const InputDecoration(labelText: 'ChordPro'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Salvar'),
          ),
          const SizedBox(height: 10),
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
      ),
    );
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
  }

  @override
  void dispose() {
    _name.dispose();
    _artist.dispose();
    _chordPro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar cifra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 12),
          TextField(
            controller: _chordPro,
            minLines: 14,
            maxLines: 24,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(labelText: 'ChordPro'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Publicar cifra'),
          ),
          const SizedBox(height: 10),
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
      ),
    );
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChordPlayerLoader(uuid: uuid)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class ChordPlayerLoader extends ConsumerWidget {
  const ChordPlayerLoader({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_chordDetailProvider(uuid));
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Nao foi possivel abrir',
          message: error.toString(),
        ),
      ),
      data: (chord) => ChordPlayerScreen(chord: chord),
    );
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

class _ChordPlayerScreenState extends State<ChordPlayerScreen> {
  final _scroll = ScrollController();
  Timer? _timer;
  var _transpose = 0;
  var _fontSize = 18.0;
  var _performance = false;
  var _autoScroll = false;
  var _autoScrollSpeed = 1.4;

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = ChordProDocument.parse(
      widget.chord.chordPro,
    ).transpose(_transpose);
    final playerItems = _PlayerItem.fromLines(document.lines);
    return Scaffold(
      backgroundColor: _performance ? Colors.black : AppColors.ink,
      appBar: _performance
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chord.chordName),
                  Text(
                    widget.chord.artist,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
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
          _PlayerControls(
            transpose: _transpose,
            fontSize: _fontSize,
            autoScroll: _autoScroll,
            autoScrollSpeed: _autoScrollSpeed,
            performance: _performance,
            onTranspose: (value) => setState(() => _transpose += value),
            onFont: (value) =>
                setState(() => _fontSize = (_fontSize + value).clamp(14, 30)),
            onAutoScroll: _toggleAutoScroll,
            onAutoScrollSpeed: (value) =>
                setState(() => _autoScrollSpeed = value),
            onExitPerformance: () => setState(() => _performance = false),
          ),
          if (document.chords.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) =>
                    Chip(label: Text(document.chords[index])),
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: document.chords.length,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 60),
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
          if (widget.bottomBar != null) widget.bottomBar!,
        ],
      ),
    );
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    _timer?.cancel();
    if (!_autoScroll) return;
    _timer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!_scroll.hasClients) return;
      final next = (_scroll.offset + _autoScrollSpeed).clamp(
        0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(next.toDouble());
    });
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.transpose,
    required this.fontSize,
    required this.autoScroll,
    required this.autoScrollSpeed,
    required this.performance,
    required this.onTranspose,
    required this.onFont,
    required this.onAutoScroll,
    required this.onAutoScrollSpeed,
    required this.onExitPerformance,
  });

  final int transpose;
  final double fontSize;
  final bool autoScroll;
  final double autoScrollSpeed;
  final bool performance;
  final ValueChanged<int> onTranspose;
  final ValueChanged<double> onFont;
  final VoidCallback onAutoScroll;
  final ValueChanged<double> onAutoScrollSpeed;
  final VoidCallback onExitPerformance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        color: performance ? Colors.black : AppColors.surface,
        child: Row(
          children: [
            IconButton(
              onPressed: () => onTranspose(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Text(
              'Tom ${transpose >= 0 ? '+$transpose' : transpose}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: () => onTranspose(1),
              icon: const Icon(Icons.add_rounded),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => onFont(-1),
              icon: const Icon(Icons.text_decrease_rounded),
            ),
            IconButton(
              onPressed: () => onFont(1),
              icon: const Icon(Icons.text_increase_rounded),
            ),
            IconButton(
              onPressed: onAutoScroll,
              color: autoScroll ? AppColors.teal : null,
              icon: const Icon(Icons.keyboard_double_arrow_down_rounded),
            ),
            PopupMenuButton<double>(
              tooltip: 'Velocidade do autoplay',
              initialValue: autoScrollSpeed,
              onSelected: onAutoScrollSpeed,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0.8, child: Text('0.5x')),
                PopupMenuItem(value: 1.4, child: Text('1x')),
                PopupMenuItem(value: 2.2, child: Text('1.5x')),
                PopupMenuItem(value: 3.2, child: Text('2x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _speedLabel(autoScrollSpeed),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (performance)
              IconButton(
                onPressed: onExitPerformance,
                icon: const Icon(Icons.fullscreen_exit_rounded),
              ),
          ],
        ),
      ),
    );
  }

  String _speedLabel(double value) {
    if (value <= 0.8) return '0.5x';
    if (value <= 1.4) return '1x';
    if (value <= 2.2) return '1.5x';
    return '2x';
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
    final lyricStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.18,
      color: performance ? Colors.white : AppColors.text,
    );
    final cueStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.05,
      color: performance ? Colors.white : AppColors.text,
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
  });

  final ChordProLine cueLine;
  final ChordProLine lyricLine;
  final TextStyle lyricStyle;
  final TextStyle cueStyle;

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
            child: _CueRichText(line: cueLine, fontSize: cueStyle.fontSize),
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
          child: _CueRichText(line: line, fontSize: fontSize),
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
              color: performance ? Colors.white : AppColors.text,
            ),
          ),
        ),
      );
    }

    final lyricStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: 0,
      height: line.chordPlacements.isEmpty ? 1.35 : 1.18,
      color: performance ? Colors.white : AppColors.text,
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
  const _CueRichText({required this.line, this.fontSize});

  final ChordProLine line;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final cueChord = line.cueChord;
    final cueLabel = line.cueLabel;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          letterSpacing: 0,
          color: AppColors.text,
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
              style: const TextStyle(
                color: AppColors.muted,
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
    final tabStyle = TextStyle(
      fontFamily: _tabFontFamily,
      fontFamilyFallback: _monoFontFallback,
      fontSize: fontSize,
      letterSpacing: 0,
      height: 1.18,
      color: performance ? Colors.white : AppColors.text,
    );
    final partStyle = tabStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: performance ? Colors.white : AppColors.text,
    );
    final chordStyle = tabStyle.copyWith(
      color: AppColors.teal,
      fontWeight: FontWeight.w900,
      height: 1.1,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: SingleChildScrollView(
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
      ),
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
