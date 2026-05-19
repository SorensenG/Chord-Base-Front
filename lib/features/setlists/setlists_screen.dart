import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_repository.dart';
import '../chords/chords_repository.dart';
import '../chords/chords_screen.dart';
import 'setlists_repository.dart';

final setlistsProvider = FutureProvider.autoDispose<List<Setlist>>((ref) {
  return ref.watch(setlistsRepositoryProvider).mine();
});

final invitesProvider = FutureProvider.autoDispose<List<SetlistInvite>>((ref) {
  return ref.watch(setlistsRepositoryProvider).invites();
});

class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(setlistsProvider);
    final invites = ref.watch(invitesProvider);
    final currentUserUuid = ref
        .watch(authControllerProvider)
        .whenOrNull(data: (user) => user?.uuid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setlists'),
        actions: [
          IconButton(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(setlistsProvider);
          ref.invalidate(invitesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            invites.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(error.toString()),
              data: (items) => Column(
                children: [
                  for (final invite in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.group_add_rounded,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Convite para ${invite.setlistName}'),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(setlistsRepositoryProvider)
                                    .acceptInvite(invite.inviteUuid);
                                ref.invalidate(invitesProvider);
                                ref.invalidate(setlistsProvider);
                              },
                              icon: const Icon(Icons.check_rounded),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(setlistsRepositoryProvider)
                                    .declineInvite(invite.inviteUuid);
                                ref.invalidate(invitesProvider);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            setlists.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar',
                message: error.toString(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: 'Monte seu primeiro repertorio',
                    message: 'Crie uma setlist e adicione cifras publicadas.',
                  );
                }
                return Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Dismissible(
                          key: ValueKey('setlist-${item.uuid}'),
                          background: const _SetlistSwipeBackground(
                            alignment: Alignment.centerLeft,
                            color: AppColors.teal,
                            icon: Icons.edit_rounded,
                            label: 'Editar',
                          ),
                          secondaryBackground: const _SetlistSwipeBackground(
                            alignment: Alignment.centerRight,
                            color: AppColors.coral,
                            icon: Icons.delete_rounded,
                            label: 'Excluir',
                          ),
                          confirmDismiss: (direction) async {
                            final isOwner = item.ownerUuid == currentUserUuid;
                            if (!isOwner) return false;
                            if (direction == DismissDirection.startToEnd) {
                              await _edit(context, ref, item);
                              return false;
                            }
                            final confirmed = await _confirmDelete(
                              context,
                              item.name,
                            );
                            if (confirmed) {
                              await ref
                                  .read(setlistsRepositoryProvider)
                                  .delete(item.uuid);
                              ref.invalidate(setlistsProvider);
                            }
                            return false;
                          },
                          child: AppCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SetlistDetailScreen(setlist: item),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.teal.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.queue_music_rounded,
                                    color: AppColors.teal,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${item.chords.length} cifras • ${item.visibility}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                        ),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SetlistForm(),
    );
    if (created == true) ref.invalidate(setlistsProvider);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetlistForm(initial: setlist),
    );
    if (updated == true) ref.invalidate(setlistsProvider);
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir setlist'),
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

class _SetlistSwipeBackground extends StatelessWidget {
  const _SetlistSwipeBackground({
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

class _SetlistForm extends ConsumerStatefulWidget {
  const _SetlistForm({this.initial});

  final Setlist? initial;

  @override
  ConsumerState<_SetlistForm> createState() => _SetlistFormState();
}

class _SetlistFormState extends ConsumerState<_SetlistForm> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  var _visibility = 'PRIVATE';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _name.text = initial.name;
      _description.text = initial.description ?? '';
      _visibility = initial.visibility;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.initial == null ? 'Nova setlist' : 'Editar setlist',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Descricao'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PRIVATE', label: Text('Privada')),
              ButtonSegment(value: 'PUBLIC', label: Text('Publica')),
              ButtonSegment(value: 'COLLABORATIVE', label: Text('Colab')),
            ],
            selected: {_visibility},
            onSelectionChanged: (value) =>
                setState(() => _visibility = value.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final initial = widget.initial;
              if (initial == null) {
                await ref
                    .read(setlistsRepositoryProvider)
                    .create(
                      name: _name.text.trim(),
                      description: _description.text.trim(),
                      visibility: _visibility,
                    );
              } else {
                await ref
                    .read(setlistsRepositoryProvider)
                    .updateDetails(
                      uuid: initial.uuid,
                      name: _name.text.trim(),
                      description: _description.text.trim(),
                      visibility: _visibility,
                    );
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(widget.initial == null ? 'Criar' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({super.key, required this.setlist});

  final Setlist setlist;

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  late Setlist _setlist = widget.setlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_setlist.name),
        actions: [
          IconButton(
            tooltip: 'Tocar setlist',
            onPressed: _setlist.chords.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetlistPlayerScreen(setlist: _setlist),
                    ),
                  ),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Editar setlist',
            onPressed: _editSetlist,
            icon: const Icon(Icons.edit_rounded),
          ),
          if (_setlist.visibility == 'COLLABORATIVE')
            IconButton(
              tooltip: 'Convidar colaborador',
              onPressed: _inviteCollaborator,
              icon: const Icon(Icons.group_add_rounded),
            ),
          IconButton(
            tooltip: 'Colaboradores',
            onPressed: _manageCollaborators,
            icon: const Icon(Icons.people_alt_rounded),
          ),
          IconButton(
            onPressed: _addChord,
            icon: const Icon(Icons.library_add_rounded),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _setlist.chords.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;
          final chords = [..._setlist.chords];
          final moved = chords.removeAt(oldIndex);
          chords.insert(newIndex, moved);
          final updated = await ref
              .read(setlistsRepositoryProvider)
              .reorder(_setlist.uuid, chords);
          setState(() => _setlist = updated);
        },
        itemBuilder: (_, index) {
          final chord = _setlist.chords[index];
          return Padding(
            key: ValueKey(chord.uuid),
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChordPlayerLoader(uuid: chord.uuid),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${index + 1}',
                    style: const TextStyle(color: AppColors.muted),
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
                          chord.artist,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final updated = await ref
                          .read(setlistsRepositoryProvider)
                          .removeChord(_setlist.uuid, chord.uuid);
                      setState(() => _setlist = updated);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editSetlist() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetlistForm(initial: _setlist),
    );
    if (updated == true) {
      final fresh = await ref
          .read(setlistsRepositoryProvider)
          .getById(_setlist.uuid);
      if (!mounted) return;
      setState(() => _setlist = fresh);
      ref.invalidate(setlistsProvider);
    }
  }

  Future<void> _inviteCollaborator() async {
    final query = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: query,
                  decoration: const InputDecoration(
                    labelText: 'Buscar usuario por @',
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<UserSearchResult>>(
                  future: query.text.trim().length < 3
                      ? Future.value(const [])
                      : ref
                            .read(setlistsRepositoryProvider)
                            .searchUsers(query.text.trim()),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <UserSearchResult>[];
                    return SizedBox(
                      height: 260,
                      child: ListView(
                        children: [
                          for (final user in items)
                            ListTile(
                              leading: ProfileAvatar(
                                userName: user.userName,
                                profileImageUrl: user.profileImageUrl,
                                radius: 18,
                              ),
                              title: Text(user.userName),
                              onTap: () async {
                                final updated = await ref
                                    .read(setlistsRepositoryProvider)
                                    .inviteCollaborator(
                                      _setlist.uuid,
                                      user.uuid,
                                    );
                                setState(() => _setlist = updated);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _manageCollaborators() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final collaborators = _setlist.collaborators;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Colaboradores',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (collaborators.isEmpty)
              const Text(
                'Nenhum colaborador.',
                style: TextStyle(color: AppColors.muted),
              ),
            for (final collaborator in collaborators)
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(collaborator.userName),
                subtitle: Text(collaborator.status),
                trailing: IconButton(
                  tooltip: 'Remover',
                  onPressed: () async {
                    final updated = await ref
                        .read(setlistsRepositoryProvider)
                        .removeCollaborator(_setlist.uuid, collaborator.uuid);
                    if (!mounted) return;
                    setState(() => _setlist = updated);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addChord() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddChordSheet(
        setlistUuid: _setlist.uuid,
        onAdded: (updated) {
          if (!mounted) return;
          setState(() => _setlist = updated);
          ref.invalidate(setlistsProvider);
        },
      ),
    );
  }
}

class SetlistPlayerScreen extends ConsumerStatefulWidget {
  const SetlistPlayerScreen({super.key, required this.setlist});

  final Setlist setlist;

  @override
  ConsumerState<SetlistPlayerScreen> createState() =>
      _SetlistPlayerScreenState();
}

class _SetlistPlayerScreenState extends ConsumerState<SetlistPlayerScreen> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final chords = widget.setlist.chords;
    if (chords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.setlist.name)),
        body: const EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'Setlist vazia',
          message: 'Adicione cifras antes de tocar.',
        ),
      );
    }

    final current = chords[_index.clamp(0, chords.length - 1)];
    return FutureBuilder<ChordDetail>(
      future: ref.read(chordsRepositoryProvider).getById(current.uuid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.setlist.name)),
            body: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Nao foi possivel tocar',
              message: snapshot.error.toString(),
            ),
          );
        }

        return ChordPlayerScreen(
          chord: snapshot.data!,
          bottomBar: _PlaylistBar(
            setlistName: widget.setlist.name,
            currentIndex: _index,
            total: chords.length,
            current: current,
            canGoPrevious: _index > 0,
            canGoNext: _index < chords.length - 1,
            onPrevious: () => setState(() => _index--),
            onNext: () => setState(() => _index++),
          ),
        );
      },
    );
  }
}

class _PlaylistBar extends StatelessWidget {
  const _PlaylistBar({
    required this.setlistName,
    required this.currentIndex,
    required this.total,
    required this.current,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String setlistName;
  final int currentIndex;
  final int total;
  final SetlistChord current;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Anterior',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$setlistName • ${currentIndex + 1}/$total',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    current.chordName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Proxima',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChordSheet extends ConsumerStatefulWidget {
  const _AddChordSheet({required this.setlistUuid, required this.onAdded});

  final String setlistUuid;
  final ValueChanged<Setlist> onAdded;

  @override
  ConsumerState<_AddChordSheet> createState() => _AddChordSheetState();
}

class _AddChordSheetState extends ConsumerState<_AddChordSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  late Future<List<ChordSummary>> _results;
  var _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _results = ref.read(chordsRepositoryProvider).mine();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adicionar cifra',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Buscar por musica ou artista',
              hintText: 'ex: Wonderwall',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _scheduleSearch,
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ChordSummary>>(
            future: _results,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Nao foi possivel buscar',
                    message: snapshot.error.toString(),
                  ),
                );
              }

              final items = snapshot.data ?? const <ChordSummary>[];
              if (items.isEmpty) {
                return SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: _activeQuery.isEmpty
                        ? 'Nenhuma cifra publicada'
                        : 'Nenhuma cifra encontrada',
                    message: _activeQuery.isEmpty
                        ? 'Publique uma cifra para adicionar na setlist.'
                        : 'Tente outro nome ou confira se a cifra foi publicada.',
                  ),
                );
              }

              return SizedBox(
                height: 260,
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.library_music_rounded,
                        color: AppColors.teal,
                      ),
                      title: Text(item.chordName),
                      subtitle: Text('${item.artist} - por ${item.addBy}'),
                      onTap: () => _addChord(item.uuid),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemCount: items.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _scheduleSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _runSearch() {
    final query = _query.text.trim();
    setState(() {
      _activeQuery = query;
      _results = query.isEmpty
          ? ref.read(chordsRepositoryProvider).mine()
          : ref.read(chordsRepositoryProvider).search(query);
    });
  }

  Future<void> _addChord(String chordUuid) async {
    final updated = await ref
        .read(setlistsRepositoryProvider)
        .addChord(widget.setlistUuid, chordUuid);
    widget.onAdded(updated);
    if (mounted) Navigator.pop(context);
  }
}
