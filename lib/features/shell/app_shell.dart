import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/app_layout.dart';
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
        HomeScreen(
          user: widget.user,
          onImportChord: _importChord,
          onCreateSetlist: _createSetlist,
          onOpenChords: _openChords,
          onReviewChords: _openReviewChords,
        ),
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
            _SideBar(
              user: widget.user,
              destinations: destinations,
              selectedIndex: _index,
              onSelected: (value) => setState(() => _index = value),
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

  void _openChords() {
    ref.read(chordLibraryFilterProvider.notifier).state =
        ChordLibraryFilter.all;
    setState(() => _index = 1);
  }

  void _openReviewChords() {
    ref.read(chordLibraryFilterProvider.notifier).state =
        ChordLibraryFilter.review;
    setState(() => _index = 1);
  }

  void _importChord() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      runChordImportFlow(context, ref);
    });
  }

  void _createSetlist() {
    setState(() => _index = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSetlistForm(context, ref);
    });
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final UserProfile user;
  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppLogo(size: 36),
                  SizedBox(width: 10),
                  Text(
                    'ChordBase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < destinations.length; index++)
                _SideBarItem(
                  destination: destinations[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    ProfileAvatar(
                      userName: user.userName,
                      profileImageUrl: user.profileImageUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideBarItem extends StatelessWidget {
  const _SideBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? AppColors.teal.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(destination.icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  destination.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
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
    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeader(
            title: 'Perfil',
            subtitle: 'Conta, foto e sessao do usuario.',
            actions: [
              FilledButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(
                      userName: user.userName,
                      profileImageUrl: user.profileImageUrl,
                      radius: 42,
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
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _pickProfileImage(ref),
                        icon: const Icon(Icons.photo_rounded),
                        label: const Text('Alterar foto'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
