import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/tutorial.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(tutorialControllerProvider.notifier)
          .startAutomaticTourIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TutorialState>(tutorialControllerProvider, (previous, next) {
      if (!next.isRunning || previous?.stepIndex == next.stepIndex) return;
      final tabIndex = _tabIndexForTutorialStep(next.stepIndex);
      if (tabIndex == _index) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = tabIndex);
      });
    });
    final tutorial = ref.watch(tutorialControllerProvider);
    final destinations = [
      _Destination(
        'Home',
        Icons.dashboard_rounded,
        HomeScreen(
          user: widget.user,
          onImportChord: _importChord,
          onCreateSetlist: _createSetlist,
          onOpenChords: _openChords,
          onOpenSetlists: _openSetlists,
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
        ProfileScreen(user: widget.user, onStartTutorial: _startTutorial),
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

    return Stack(
      children: [
        Scaffold(
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
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: [
                    for (final item in destinations)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                  ],
                ),
        ),
        if (tutorial.isRunning)
          TutorialOverlay(
            stepIndex: tutorial.stepIndex,
            onBack: ref.read(tutorialControllerProvider.notifier).previousStep,
            onNext: () {
              ref.read(tutorialControllerProvider.notifier).nextStep();
            },
            onSkip: () {
              ref.read(tutorialControllerProvider.notifier).skipTour();
            },
          ),
      ],
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

  void _openSetlists() {
    setState(() => _index = 2);
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

  void _startTutorial() {
    setState(() => _index = 0);
    ref.read(tutorialControllerProvider.notifier).startManualTour();
  }

  int _tabIndexForTutorialStep(int stepIndex) {
    return switch (stepIndex) {
      0 => 0,
      1 => 1,
      2 => 2,
      3 => 3,
      4 => 1,
      _ => 0,
    };
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
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onStartTutorial,
  });

  final UserProfile user;
  final VoidCallback onStartTutorial;

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
                          OutlinedButton.icon(
                            onPressed: onStartTutorial,
                            icon: const Icon(Icons.tips_and_updates_rounded),
                            label: const Text('Ver tutorial novamente'),
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

class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.stepIndex,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final int stepIndex;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _steps = [
    _TutorialStep(
      icon: Icons.dashboard_rounded,
      title: 'Comece pela Home',
      body:
          'A Home mostra pendencias, atividades recentes e atalhos para importar cifras ou montar setlists.',
    ),
    _TutorialStep(
      icon: Icons.library_music_rounded,
      title: 'Organize suas cifras',
      body:
          'Em Cifras voce busca sua biblioteca, revisa importacoes e abre qualquer musica para tocar.',
    ),
    _TutorialStep(
      icon: Icons.queue_music_rounded,
      title: 'Monte repertorios',
      body:
          'Em Setlists voce agrupa musicas por ensaio, culto, show ou estudo e toca tudo em sequencia.',
    ),
    _TutorialStep(
      icon: Icons.person_rounded,
      title: 'Ajuste seu perfil',
      body:
          'No Perfil voce troca foto, escreve sua descricao, escolhe o tema e pode abrir este tutorial de novo.',
    ),
    _TutorialStep(
      icon: Icons.play_arrow_rounded,
      title: 'Use o player de cifra',
      body:
          'Ao abrir uma cifra, use tom, tamanho do texto, lista de acordes, auto rolagem e modo palco.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final index = stepIndex.clamp(0, _steps.length - 1);
    final step = _steps[index];
    final isLast = index == _steps.length - 1;
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.48),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Align(
              alignment: compact ? Alignment.bottomCenter : Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: colors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Icon(step.icon, color: AppColors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Passo ${index + 1} de ${_steps.length}',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  step.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(step.body, style: TextStyle(color: colors.muted)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (index + 1) / _steps.length,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            onPressed: onSkip,
                            child: const Text('Pular'),
                          ),
                          OutlinedButton(
                            onPressed: index == 0 ? null : onBack,
                            child: const Text('Voltar'),
                          ),
                          FilledButton(
                            onPressed: onNext,
                            child: Text(isLast ? 'Concluir' : 'Proximo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
