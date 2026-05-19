import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_repository.dart';
import '../chords/chords_screen.dart';
import '../setlists/setlists_screen.dart';
import 'home_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.user});

  final UserProfile user;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      _Destination(
        'Home',
        Icons.dashboard_rounded,
        HomeScreen(user: widget.user),
      ),
      const _Destination('Cifras', Icons.library_music_rounded, ChordsScreen()),
      const _Destination(
        'Setlists',
        Icons.queue_music_rounded,
        SetlistsScreen(),
      ),
      _Destination(
        'Perfil',
        Icons.person_rounded,
        ProfileScreen(user: widget.user),
      ),
      if (widget.user.isAdmin)
        const _Destination(
          'Admin',
          Icons.admin_panel_settings_rounded,
          AdminScreen(),
        ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(child: destinations[_index].screen),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.teal.withValues(alpha: 0.16),
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileAvatar(
                  userName: user.userName,
                  profileImageUrl: user.profileImageUrl,
                  radius: 48,
                  onTap: () => _pickProfileImage(ref),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: IconButton.filled(
                    tooltip: 'Alterar foto',
                    onPressed: () => _pickProfileImage(ref),
                    icon: const Icon(Icons.photo_camera_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(user.userName, style: Theme.of(context).textTheme.headlineSmall),
          Text(user.email, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _pickProfileImage(ref),
            icon: const Icon(Icons.photo_rounded),
            label: const Text('Alterar foto de perfil'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage(WidgetRef ref) async {
    final image = await pickProfileImageDataUrl();
    if (image == null) return;
    await ref.read(authControllerProvider.notifier).updateProfileImage(image);
  }
}
