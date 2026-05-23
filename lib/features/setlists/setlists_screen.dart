import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/recent_activity_store.dart';
import '../../core/theme.dart';
import '../../core/user_messages.dart';
import '../../shared/widgets/app_layout.dart';
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

Future<bool> showSetlistForm(
  BuildContext context,
  WidgetRef ref, {
  Setlist? initial,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SetlistForm(initial: initial),
  );
  if (changed == true) {
    ref.invalidate(setlistsProvider);
  }
  return changed == true;
}

class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final setlists = ref.watch(setlistsProvider);
    final invites = ref.watch(invitesProvider);
    final currentUserUuid = ref
        .watch(authControllerProvider)
        .whenOrNull(data: (user) => user?.uuid);
    return AppScaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(setlistsProvider);
          ref.invalidate(invitesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            PageHeader(
              title: 'Setlists',
              subtitle: 'Organize repertorios e abra tudo no modo palco.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova setlist'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            invites.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(userMessage(error)),
              data: (items) => Column(
                children: [
                  for (final invite in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.group_add_rounded,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.setlistName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Convite de ${invite.ownerUserName}',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
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
            const SectionHeader(
              title: 'Meus repertorios',
              subtitle: 'Setlists prontas para ensaio e apresentacao.',
            ),
            const SizedBox(height: 12),
            setlists.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar',
                message: userMessage(error),
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
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SetlistSummaryRow(
                          setlist: item,
                          canManage: item.ownerUuid == currentUserUuid,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SetlistDetailScreen(setlist: item),
                            ),
                          ),
                          onEdit: () => _edit(context, ref, item),
                          onDelete: () async {
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
                          },
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
    await showSetlistForm(context, ref);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    await showSetlistForm(context, ref, initial: setlist);
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

class _SetlistSummaryRow extends StatelessWidget {
  const _SetlistSummaryRow({
    required this.setlist,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Setlist setlist;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${setlist.chords.length} cifras • ${setlist.ownerUserName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(label: setlist.visibility),
              const SizedBox(width: 6),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Acoes da setlist',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordSetlist());
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return AppScaffold(
      appBar: AppBar(title: const Text('Setlist')),
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              onPressed: _addChord,
              icon: const Icon(Icons.library_add_rounded),
              label: const Text('Adicionar cifra'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 24,
              compact ? 12 : 18,
              compact ? 16 : 24,
              12,
            ),
            child: PageHeader(
              title: _setlist.name,
              subtitle:
                  '${_setlist.chords.length} cifras • ${_setlist.visibility}',
              actions: compact
                  ? [
                      FilledButton.icon(
                        onPressed: _setlist.chords.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SetlistPlayerScreen(setlist: _setlist),
                                ),
                              ),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Palco'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Acoes da setlist',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (value) {
                          if (value == 'edit') _editSetlist();
                          if (value == 'invite') _inviteCollaborator();
                          if (value == 'collaborators') _manageCollaborators();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar setlist'),
                          ),
                          if (_setlist.visibility == 'COLLABORATIVE')
                            const PopupMenuItem(
                              value: 'invite',
                              child: Text('Convidar colaborador'),
                            ),
                          const PopupMenuItem(
                            value: 'collaborators',
                            child: Text('Colaboradores'),
                          ),
                        ],
                      ),
                    ]
                  : [
                      FilledButton.icon(
                        onPressed: _setlist.chords.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SetlistPlayerScreen(setlist: _setlist),
                                ),
                              ),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Modo palco'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _addChord,
                        icon: const Icon(Icons.library_add_rounded),
                        label: const Text('Adicionar cifra'),
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
                    ],
            ),
          ),
          Expanded(
            child: _setlist.chords.isEmpty
                ? _EmptySetlist(onAddChord: _addChord)
                : ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 24,
                      8,
                      compact ? 16 : 24,
                      compact ? 104 : 24,
                    ),
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
                      return _SetlistChordRow(
                        key: ValueKey(chord.uuid),
                        chord: chord,
                        index: index,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChordPlayerLoader(uuid: chord.uuid),
                          ),
                        ),
                        onDelete: () async {
                          final updated = await ref
                              .read(setlistsRepositoryProvider)
                              .removeChord(_setlist.uuid, chord.uuid);
                          setState(() => _setlist = updated);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordSetlist() async {
    if (!mounted) return;
    await ref
        .read(recentActivityStoreProvider)
        .save(
          RecentActivity(
            type: RecentActivityType.setlist,
            uuid: _setlist.uuid,
            title: _setlist.name,
            subtitle: '${_setlist.chords.length} cifras',
          ),
        );
    ref.invalidate(recentActivityProvider);
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
      await _recordSetlist();
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
              Text(
                'Nenhum colaborador.',
                style: TextStyle(color: context.appColors.muted),
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
        onAdded: (updated, imported) {
          if (!mounted) return;
          setState(() => _setlist = updated);
          ref.invalidate(setlistsProvider);
          if (imported) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cifra criada e adicionada a setlist.'),
              ),
            );
          }
        },
      ),
    );
  }
}

class _EmptySetlist extends StatelessWidget {
  const _EmptySetlist({required this.onAddChord});

  final VoidCallback onAddChord;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.queue_music_rounded,
              size: 42,
              color: AppColors.teal,
            ),
            const SizedBox(height: 14),
            Text(
              'Sua setlist esta vazia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Busque uma cifra existente ou importe um arquivo novo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddChord,
              icon: const Icon(Icons.library_add_rounded),
              label: const Text('Adicionar cifra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetlistChordRow extends StatelessWidget {
  const _SetlistChordRow({
    super.key,
    required this.chord,
    required this.index,
    required this.onOpen,
    required this.onDelete,
  });

  final SetlistChord chord;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chord.chordName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        chord.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover da setlist',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                Icon(Icons.drag_indicator_rounded, color: colors.muted),
              ],
            ),
          ),
        ),
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(recentActivityStoreProvider)
          .save(
            RecentActivity(
              type: RecentActivityType.setlist,
              uuid: widget.setlist.uuid,
              title: widget.setlist.name,
              subtitle: '${widget.setlist.chords.length} cifras',
            ),
          );
      ref.invalidate(recentActivityProvider);
    });
  }

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
              message: userMessage(snapshot.error!),
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
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.line)),
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
                    style: TextStyle(color: colors.muted, fontSize: 12),
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
  final void Function(Setlist, bool imported) onAdded;

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
    _results = _loadPublishedChords();
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
          const SizedBox(height: 6),
          Text(
            'Escolha uma cifra publicada ou importe um arquivo novo.',
            style: TextStyle(color: context.appColors.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _importNewChord,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Importar nova cifra'),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: _activeQuery.isEmpty
                ? 'Suas cifras publicadas'
                : 'Cifras publicadas encontradas',
            subtitle: _activeQuery.isEmpty
                ? 'Toque para adicionar a setlist.'
                : 'Resultados disponiveis para adicionar.',
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
                    message: userMessage(snapshot.error!),
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
      _results = _loadPublishedChords(query);
    });
  }

  Future<List<ChordSummary>> _loadPublishedChords([String query = '']) async {
    final repository = ref.read(chordsRepositoryProvider);
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      final items = await repository.mine();
      return items.where((item) => item.isPublished).toList();
    }

    final results = await Future.wait([
      repository.mine(),
      repository.search(query),
    ]);
    final personalMatches = results.first.where(
      (item) =>
          item.isPublished &&
          (item.chordName.toLowerCase().contains(normalizedQuery) ||
              item.artist.toLowerCase().contains(normalizedQuery)),
    );
    return {
      for (final item in [...personalMatches, ...results.last])
        if (item.isPublished) item.uuid: item,
    }.values.toList();
  }

  Future<void> _importNewChord() async {
    final uuid = await runChordImportFlow(
      context,
      ref,
      refreshSearchQuery: _activeQuery,
      showSuccessMessage: false,
    );
    if (uuid == null || !mounted) return;
    await _addChord(uuid, imported: true);
  }

  Future<void> _addChord(String chordUuid, {bool imported = false}) async {
    try {
      final updated = await ref
          .read(setlistsRepositoryProvider)
          .addChord(widget.setlistUuid, chordUuid);
      widget.onAdded(updated, imported);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }
}
