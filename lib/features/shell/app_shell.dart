import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/user_messages.dart';
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
    final colors = context.appColors;

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
              backgroundColor: colors.surface,
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
    final colors = context.appColors;
    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.line)),
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
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: colors.line),
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
                            style: TextStyle(color: colors.muted, fontSize: 12),
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
    final colors = context.appColors;
    final color = selected ? colors.text : colors.muted;
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
    final colors = context.appColors;
    final themePreference = ref.watch(themeModeControllerProvider);
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
              color: colors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: colors.line),
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
                      Text(user.email, style: TextStyle(color: colors.muted)),
                      if (user.description != null &&
                          user.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.description!,
                          style: TextStyle(color: colors.muted),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickProfileImage(ref),
                            icon: const Icon(Icons.photo_rounded),
                            label: const Text('Alterar foto'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _editProfile(context, ref, user),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Editar perfil'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aparencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha o tema do app neste dispositivo.',
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<AppThemePreference>(
                  segments: [
                    for (final item in AppThemePreference.values)
                      ButtonSegment(value: item, label: Text(item.label)),
                  ],
                  selected: {themePreference},
                  onSelectionChanged: (values) {
                    ref
                        .read(themeModeControllerProvider.notifier)
                        .setPreference(values.single);
                  },
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

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final controller = TextEditingController(text: user.description ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Descricao',
            hintText:
                'Compartilhe um pouco sobre voce, sua trajetoria na musica e seus gostos.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            profileImageUrl: user.profileImageUrl,
            description: result.isEmpty ? null : result,
          );
    } catch (error) {
      if (!context.mounted) return;
      showUserMessage(context, error);
    }
  }
}
