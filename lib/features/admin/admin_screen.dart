import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../chords/chords_repository.dart';
import '../chords/chords_screen.dart';
import '../setlists/setlists_repository.dart';
import '../setlists/setlists_screen.dart';
import 'admin_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usuarios'),
              Tab(text: 'Bandas'),
              Tab(text: 'Escolas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminUsersProvider),
              child: users.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    EmptyState(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Nao foi possivel carregar usuarios',
                      message: error.toString(),
                    ),
                  ],
                ),
                data: (items) => _UsersList(users: items),
              ),
            ),
            const _FutureAdminArea(
              icon: Icons.groups_rounded,
              title: 'Bandas',
              message:
                  'Espaco reservado para aprovar, editar e acompanhar bandas.',
            ),
            const _FutureAdminArea(
              icon: Icons.school_rounded,
              title: 'Escolas',
              message:
                  'Espaco reservado para escolas, turmas e permissoes futuras.',
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Nenhum usuario',
            message: 'Quando houver cadastros, eles aparecem aqui.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Usuarios', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminUserDetailScreen(user: user),
                ),
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    userName: user.userName,
                    profileImageUrl: user.profileImageUrl,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.userName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final role in user.roles)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(role.replaceFirst('ROLE_', '')),
                              ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: user.active
                                  ? AppColors.teal.withValues(alpha: 0.16)
                                  : AppColors.coral.withValues(alpha: 0.16),
                              label: Text(user.active ? 'ATIVO' : 'INATIVO'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'Tipos do usuario',
                        onPressed: () => _editRoles(context, ref, user),
                        icon: const Icon(Icons.badge_rounded),
                      ),
                      Switch(
                        value: user.isAdmin,
                        onChanged: (enabled) =>
                            _setAdmin(context, ref, user, enabled),
                      ),
                      Switch(
                        value: user.active,
                        onChanged: (enabled) =>
                            _setActive(context, ref, user, enabled),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _setAdmin(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
    bool enabled,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).setAdmin(user, enabled);
      ref.invalidate(adminUsersProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
    bool enabled,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).setActive(user, enabled);
      ref.invalidate(adminUsersProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editRoles(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final selected = {...user.roles};
    final roles = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          const allRoles = [
            'ROLE_USER',
            'ROLE_ADMIN',
            'ROLE_BAND',
            'ROLE_SCHOOL',
          ];
          return AlertDialog(
            title: const Text('Tipos do usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in allRoles)
                  CheckboxListTile(
                    value: selected.contains(role),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selected.add(role);
                        } else {
                          selected.remove(role);
                        }
                      });
                    },
                    title: Text(role.replaceFirst('ROLE_', '')),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected.toList()),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    if (roles == null) return;
    try {
      await ref.read(adminRepositoryProvider).setRoles(user, roles);
      ref.invalidate(adminUsersProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chords = ref.watch(adminUserChordsProvider(user.uuid));
    final setlists = ref.watch(adminUserSetlistsProvider(user.uuid));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.userName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cifras'),
              Tab(text: 'Setlists'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            chords.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar cifras',
                message: error.toString(),
              ),
              data: (items) => _AdminChordList(user: user, items: items),
            ),
            setlists.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar setlists',
                message: error.toString(),
              ),
              data: (items) => _AdminSetlistList(user: user, items: items),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminChordList extends ConsumerWidget {
  const _AdminChordList({required this.user, required this.items});

  final AdminUser user;
  final List<ChordSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.library_music_rounded,
        title: 'Nenhuma cifra',
        message: 'Este usuario ainda nao possui cifras.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final chord in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('admin-chord-${chord.uuid}'),
              background: const _AdminSwipeBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.teal,
                icon: Icons.edit_rounded,
                label: 'Editar',
              ),
              secondaryBackground: const _AdminSwipeBackground(
                alignment: Alignment.centerRight,
                color: AppColors.coral,
                icon: Icons.delete_rounded,
                label: 'Excluir',
              ),
              confirmDismiss: (direction) async {
                try {
                  if (direction == DismissDirection.startToEnd) {
                    final detail = await ref
                        .read(chordsRepositoryProvider)
                        .getById(chord.uuid);
                    if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChordEditScreen(chord: detail),
                        ),
                      );
                      ref.invalidate(adminUserChordsProvider(user.uuid));
                    }
                    return false;
                  }
                  await ref.read(chordsRepositoryProvider).delete(chord.uuid);
                  ref.invalidate(adminUserChordsProvider(user.uuid));
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                  return false;
                }
                return false;
              },
              child: AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChordPlayerLoader(uuid: chord.uuid),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.library_music_rounded,
                    color: AppColors.teal,
                  ),
                  title: Text(chord.chordName),
                  subtitle: Text('${chord.artist} • ${chord.status}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminSetlistList extends ConsumerWidget {
  const _AdminSetlistList({required this.user, required this.items});

  final AdminUser user;
  final List<Setlist> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Nenhuma setlist',
        message: 'Este usuario ainda nao possui setlists.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final setlist in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('admin-setlist-${setlist.uuid}'),
              background: const _AdminSwipeBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.teal,
                icon: Icons.edit_rounded,
                label: 'Gerenciar',
              ),
              secondaryBackground: const _AdminSwipeBackground(
                alignment: Alignment.centerRight,
                color: AppColors.coral,
                icon: Icons.delete_rounded,
                label: 'Excluir',
              ),
              confirmDismiss: (direction) async {
                try {
                  if (direction == DismissDirection.startToEnd) {
                    if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SetlistDetailScreen(setlist: setlist),
                        ),
                      );
                      ref.invalidate(adminUserSetlistsProvider(user.uuid));
                    }
                    return false;
                  }
                  await ref
                      .read(setlistsRepositoryProvider)
                      .delete(setlist.uuid);
                  ref.invalidate(adminUserSetlistsProvider(user.uuid));
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                  return false;
                }
                return false;
              },
              child: AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SetlistDetailScreen(setlist: setlist),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.queue_music_rounded,
                    color: AppColors.gold,
                  ),
                  title: Text(setlist.name),
                  subtitle: Text(
                    '${setlist.chords.length} cifras • ${setlist.visibility}',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminSwipeBackground extends StatelessWidget {
  const _AdminSwipeBackground({
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

class _FutureAdminArea extends StatelessWidget {
  const _FutureAdminArea({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [EmptyState(icon: icon, title: title, message: message)],
    );
  }
}
