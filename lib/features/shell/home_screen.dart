import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/recent_activity_store.dart';
import '../../core/theme.dart';
import '../../core/user_messages.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/app_layout.dart';
import '../chords/chords_repository.dart';
import '../chords/chords_screen.dart';
import '../setlists/setlists_repository.dart';
import '../setlists/setlists_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onImportChord,
    required this.onCreateSetlist,
    required this.onOpenChords,
    required this.onOpenSetlists,
    required this.onReviewChords,
  });

  final UserProfile user;
  final VoidCallback onImportChord;
  final VoidCallback onCreateSetlist;
  final VoidCallback onOpenChords;
  final VoidCallback onOpenSetlists;
  final VoidCallback onReviewChords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(_setlistsProvider);
    final invites = ref.watch(_invitesProvider);
    final chords = ref.watch(myChordsProvider);
    final recent = ref.watch(recentActivityProvider);
    final pendingValue = invites.maybeWhen(
      data: (pendingInvites) => chords.maybeWhen(
        data: (items) =>
            '${pendingInvites.length + items.where((item) => item.status != 'PUBLISHED').length}',
        orElse: () => '-',
      ),
      orElse: () => '-',
    );
    final compact = MediaQuery.sizeOf(context).width < 640;
    return AppScaffold(
      body: SafeArea(
        top: compact,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_setlistsProvider);
            ref.invalidate(_invitesProvider);
            ref.invalidate(myChordsProvider);
            ref.invalidate(recentActivityProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 24,
              compact ? 14 : 24,
              compact ? 16 : 24,
              compact ? 92 : 24,
            ),
            children: [
              PageHeader(
                title: 'Ola, ${user.userName}',
                subtitle:
                    'Gerencie suas cifras e setlists, e continue tocando de onde parou.',
                leading: compact ? const AppLogo(size: 42) : null,
                actions: [
                  IconButton(
                    tooltip: 'Pendencias',
                    onPressed: () => _showNotifications(context, ref),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (compact)
                Column(
                  children: [
                    QuickActionButton(
                      icon: Icons.upload_file_rounded,
                      label: 'Importar cifra',
                      description: 'PDF ou TXT',
                      fullWidth: true,
                      onTap: onImportChord,
                    ),
                    const SizedBox(height: 10),
                    QuickActionButton(
                      icon: Icons.queue_music_rounded,
                      label: 'Criar setlist',
                      description: 'Monte o repertorio',
                      color: AppColors.gold,
                      fullWidth: true,
                      onTap: onCreateSetlist,
                    ),
                    const SizedBox(height: 10),
                    QuickActionButton(
                      icon: Icons.search_rounded,
                      label: 'Buscar musica',
                      description: 'Encontre uma cifra',
                      color: AppColors.blue,
                      fullWidth: true,
                      onTap: onOpenChords,
                    ),
                  ],
                )
              else
                ActionToolbar(
                  children: [
                    QuickActionButton(
                      icon: Icons.upload_file_rounded,
                      label: 'Importar cifra',
                      description: 'PDF ou TXT',
                      onTap: onImportChord,
                    ),
                    QuickActionButton(
                      icon: Icons.queue_music_rounded,
                      label: 'Criar setlist',
                      description: 'Monte o repertorio',
                      color: AppColors.gold,
                      onTap: onCreateSetlist,
                    ),
                    QuickActionButton(
                      icon: Icons.search_rounded,
                      label: 'Buscar musica',
                      description: 'Encontre uma cifra',
                      color: AppColors.blue,
                      onTap: onOpenChords,
                    ),
                  ],
                ),
              const SizedBox(height: 22),
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        key: const ValueKey('home-metric-chords'),
                        icon: Icons.library_music_rounded,
                        label: 'Cifras',
                        value: chords.maybeWhen(
                          data: (items) => '${items.length}',
                          orElse: () => '-',
                        ),
                        color: AppColors.teal,
                        width: double.infinity,
                        onTap: onOpenChords,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        key: const ValueKey('home-metric-setlists'),
                        icon: Icons.queue_music_rounded,
                        label: 'Setlists',
                        value: setlists.maybeWhen(
                          data: (items) => '${items.length}',
                          orElse: () => '-',
                        ),
                        color: AppColors.gold,
                        width: double.infinity,
                        onTap: onOpenSetlists,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        key: const ValueKey('home-metric-pending'),
                        icon: Icons.pending_actions_rounded,
                        label: 'Pendencias',
                        value: pendingValue,
                        color: AppColors.blue,
                        width: double.infinity,
                        onTap: () => _showNotifications(context, ref),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      key: const ValueKey('home-metric-chords'),
                      icon: Icons.library_music_rounded,
                      label: 'Cifras',
                      value: chords.maybeWhen(
                        data: (items) => '${items.length}',
                        orElse: () => '-',
                      ),
                      color: AppColors.teal,
                      onTap: onOpenChords,
                    ),
                    _Metric(
                      key: const ValueKey('home-metric-setlists'),
                      icon: Icons.queue_music_rounded,
                      label: 'Setlists',
                      value: setlists.maybeWhen(
                        data: (items) => '${items.length}',
                        orElse: () => '-',
                      ),
                      color: AppColors.gold,
                      onTap: onOpenSetlists,
                    ),
                    _Metric(
                      key: const ValueKey('home-metric-pending'),
                      icon: Icons.pending_actions_rounded,
                      label: 'Pendencias',
                      value: pendingValue,
                      color: AppColors.blue,
                      onTap: () => _showNotifications(context, ref),
                    ),
                  ],
                ),
              const SizedBox(height: 26),
              const SectionHeader(
                title: 'Continuar tocando',
                subtitle: 'Ultimo item aberto neste dispositivo.',
              ),
              const SizedBox(height: 12),
              recent.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => _RecentFallback(setlists: setlists),
                data: (activity) {
                  if (activity != null) {
                    return _RecentActivityPanel(
                      activity: activity,
                      onOpen: () => _openRecent(context, ref, activity),
                    );
                  }
                  return _RecentFallback(setlists: setlists);
                },
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Pendencias',
                subtitle: 'Itens que pedem sua atencao antes do ensaio.',
              ),
              const SizedBox(height: 12),
              invites.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => Text(userMessage(error)),
                data: (items) => _PendingPanel(
                  inviteCount: items.length,
                  chordCount: chords.maybeWhen(
                    data: (items) => items
                        .where((item) => item.status != 'PUBLISHED')
                        .length,
                    orElse: () => 0,
                  ),
                  onTap: () => _showNotifications(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRecent(
    BuildContext context,
    WidgetRef ref,
    RecentActivity activity,
  ) async {
    if (activity.type == RecentActivityType.chord) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChordPlayerLoader(uuid: activity.uuid),
        ),
      );
      return;
    }

    try {
      Setlist? cached;
      ref
          .read(_setlistsProvider)
          .maybeWhen(
            data: (items) {
              for (final item in items) {
                if (item.uuid == activity.uuid) {
                  cached = item;
                  break;
                }
              }
            },
            orElse: () {},
          );
      final setlist =
          cached ??
          await ref.read(setlistsRepositoryProvider).getById(activity.uuid);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SetlistDetailScreen(setlist: setlist),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotificationsBottomSheet(onReviewChords: onReviewChords),
    );
  }
}

final _setlistsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(setlistsRepositoryProvider).mine();
});

final _invitesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(setlistsRepositoryProvider).invites();
});

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.width = 112,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final double width;

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
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentFallback extends StatelessWidget {
  const _RecentFallback({required this.setlists});

  final AsyncValue<List<Setlist>> setlists;

  @override
  Widget build(BuildContext context) {
    return setlists.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(userMessage(error)),
      data: (items) => Column(
        children: [
          for (final item in items.take(2))
            _SetlistHomeRow(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SetlistDetailScreen(setlist: item),
                ),
              ),
            ),
          if (items.isEmpty)
            const _EmptyPanel(
              icon: Icons.queue_music_rounded,
              text: 'Abra uma cifra ou crie uma setlist para continuar daqui.',
            ),
        ],
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.activity, required this.onOpen});

  final RecentActivity activity;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isSetlist = activity.type == RecentActivityType.setlist;
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSetlist
                    ? Icons.queue_music_rounded
                    : Icons.library_music_rounded,
                color: isSetlist ? AppColors.gold : AppColors.teal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activity.subtitle ??
                          (isSetlist ? 'Setlist recente' : 'Cifra recente'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetlistHomeRow extends StatelessWidget {
  const _SetlistHomeRow({required this.item, required this.onTap});

  final Setlist item;
  final VoidCallback onTap;

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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded, color: AppColors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.chords.length} cifras • ${item.ownerUserName}',
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: item.visibility),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingPanel extends StatelessWidget {
  const _PendingPanel({
    required this.inviteCount,
    required this.chordCount,
    required this.onTap,
  });

  final int inviteCount;
  final int chordCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idle = inviteCount == 0 && chordCount == 0;
    final colors = context.appColors;
    return Material(
      color: colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                idle
                    ? Icons.check_circle_outline_rounded
                    : Icons.pending_actions,
                color: idle ? AppColors.teal : AppColors.gold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  idle
                      ? 'Tudo limpo por aqui. Nenhum convite ou cifra em revisao.'
                      : '$inviteCount convite(s) e $chordCount cifra(s) para revisar.',
                  style: TextStyle(color: colors.muted),
                ),
              ),
              Icon(Icons.keyboard_arrow_up_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsBottomSheet extends ConsumerWidget {
  const _NotificationsBottomSheet({required this.onReviewChords});

  final VoidCallback onReviewChords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final invites = ref.watch(_invitesProvider);
    final chords = ref.watch(myChordsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text('Pendencias', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Convites e cifras que precisam de revisao.',
              style: TextStyle(color: colors.muted),
            ),
            const SizedBox(height: 18),
            invites.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(userMessage(error)),
              data: (items) => Column(
                children: [
                  for (final invite in items)
                    _InviteTile(
                      invite: invite,
                      onAccepted: _openAcceptedSetlist,
                    ),
                  if (items.isEmpty)
                    const _EmptyPanel(
                      icon: Icons.group_add_rounded,
                      text: 'Nenhum convite pendente.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            chords.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(userMessage(error)),
              data: (items) {
                final reviewItems = items
                    .where((item) => item.status != 'PUBLISHED')
                    .toList();
                if (reviewItems.isEmpty) {
                  return const _EmptyPanel(
                    icon: Icons.library_music_rounded,
                    text: 'Nenhuma cifra em revisao.',
                  );
                }
                return Column(
                  children: [
                    for (final chord in reviewItems.take(4))
                      ListTile(
                        leading: const Icon(Icons.rate_review_rounded),
                        title: Text(chord.chordName),
                        subtitle: Text(chord.artist),
                        trailing: StatusBadge(label: chord.status),
                        onTap: () {
                          Navigator.of(context).pop();
                          onReviewChords();
                        },
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

  Future<void> _openAcceptedSetlist(
    BuildContext context,
    WidgetRef ref,
    SetlistInvite invite,
  ) async {
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(setlistsRepositoryProvider)
          .acceptInvite(invite.inviteUuid);
      ref.invalidate(_invitesProvider);
      ref.invalidate(invitesProvider);
      ref.invalidate(_setlistsProvider);
      ref.invalidate(setlistsProvider);
      final setlist = await ref
          .read(setlistsRepositoryProvider)
          .getById(invite.setlistUuid);
      if (context.mounted) navigator.pop();
      await rootNavigator.push(
        MaterialPageRoute(
          builder: (_) => SetlistDetailScreen(setlist: setlist),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(error))));
    }
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite, required this.onAccepted});

  final SetlistInvite invite;
  final Future<void> Function(BuildContext, WidgetRef, SetlistInvite)
  onAccepted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_add_rounded, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.setlistName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Convite de ${invite.ownerUserName}',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recusar',
            onPressed: () async {
              try {
                await ref
                    .read(setlistsRepositoryProvider)
                    .declineInvite(invite.inviteUuid);
                ref.invalidate(_invitesProvider);
                ref.invalidate(invitesProvider);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(userMessage(error))));
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Aceitar e abrir',
            onPressed: () => onAccepted(context, ref, invite),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.muted)),
          ),
        ],
      ),
    );
  }
}
