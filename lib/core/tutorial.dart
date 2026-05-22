import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum TutorialStatus { loading, inactive, running, completed }

class TutorialState {
  const TutorialState({
    required this.status,
    this.stepIndex = 0,
    this.completed = false,
  });

  final TutorialStatus status;
  final int stepIndex;
  final bool completed;

  bool get isRunning => status == TutorialStatus.running;

  TutorialState copyWith({
    TutorialStatus? status,
    int? stepIndex,
    bool? completed,
  }) {
    return TutorialState(
      status: status ?? this.status,
      stepIndex: stepIndex ?? this.stepIndex,
      completed: completed ?? this.completed,
    );
  }
}

final tutorialControllerProvider =
    StateNotifierProvider<TutorialController, TutorialState>((ref) {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(),
        webOptions: WebOptions(
          dbName: 'chordbase_secure',
          publicKey: 'chordbase',
        ),
      );
      return TutorialController(storage);
    });

class TutorialController extends StateNotifier<TutorialState> {
  TutorialController(this._storage)
    : super(const TutorialState(status: TutorialStatus.loading)) {
    _restoreFuture = _restore();
    unawaited(_restoreFuture);
  }

  static const storageKey = 'chordbase.tutorial.v1.completed';
  static const stepCount = 5;

  final FlutterSecureStorage _storage;
  late final Future<void> _restoreFuture;

  Future<void> startAutomaticTourIfNeeded() async {
    await _restoreFuture;
    if (state.completed || state.isRunning) return;
    state = state.copyWith(status: TutorialStatus.running, stepIndex: 0);
  }

  Future<void> startManualTour() async {
    await _restoreFuture;
    state = state.copyWith(status: TutorialStatus.running, stepIndex: 0);
  }

  void previousStep() {
    if (!state.isRunning) return;
    final nextIndex = state.stepIndex <= 0 ? 0 : state.stepIndex - 1;
    state = state.copyWith(stepIndex: nextIndex);
  }

  Future<void> nextStep() async {
    if (!state.isRunning) return;
    if (state.stepIndex >= stepCount - 1) {
      await completeTour();
      return;
    }
    state = state.copyWith(stepIndex: state.stepIndex + 1);
  }

  Future<void> skipTour() => _markCompleted();

  Future<void> completeTour() => _markCompleted();

  Future<void> _restore() async {
    final value = await _storage.read(key: storageKey);
    final completed = value == 'true';
    state = TutorialState(
      status: completed ? TutorialStatus.completed : TutorialStatus.inactive,
      completed: completed,
    );
  }

  Future<void> _markCompleted() async {
    await _restoreFuture;
    await _storage.write(key: storageKey, value: 'true');
    state = const TutorialState(
      status: TutorialStatus.completed,
      completed: true,
    );
  }
}
