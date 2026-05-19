import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_logo.dart';
import '../chords/chords_repository.dart';
import '../setlists/setlists_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(_setlistsProvider);
    final invites = ref.watch(_invitesProvider);
    final chords = ref.watch(myChordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Ola, ${user.userName}'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_setlistsProvider);
          ref.invalidate(_invitesProvider);
          ref.invalidate(myChordsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const AppLogo(size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cifras, setlists e palco em um so lugar.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  icon: Icons.library_music_rounded,
                  label: 'Cifras',
                  value: chords.maybeWhen(
                    data: (items) => '${items.length}',
                    orElse: () => '-',
                  ),
                  color: AppColors.teal,
                ),
                _Metric(
                  icon: Icons.queue_music_rounded,
                  label: 'Setlists',
                  value: setlists.maybeWhen(
                    data: (items) => '${items.length}',
                    orElse: () => '-',
                  ),
                  color: AppColors.coral,
                ),
                _Metric(
                  icon: Icons.group_add_rounded,
                  label: 'Convites',
                  value: invites.maybeWhen(
                    data: (items) => '${items.length}',
                    orElse: () => '-',
                  ),
                  color: AppColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Minhas setlists',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            setlists.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (items) => Column(
                children: [
                  for (final item in items.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.queue_music_rounded,
                              color: AppColors.teal,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          ],
                        ),
                      ),
                    ),
                  if (items.isEmpty)
                    const Text(
                      'Nenhuma setlist criada ainda.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Convites', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            invites.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(error.toString()),
              data: (items) => Text(
                items.isEmpty
                    ? 'Nenhum convite pendente.'
                    : '${items.length} convite(s) aguardando resposta.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
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
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
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
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
