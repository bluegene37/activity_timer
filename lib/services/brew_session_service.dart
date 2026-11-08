import 'package:signals/signals.dart';

import '../controllers/brew_run_controller.dart';
import '../models/brew_recipe.dart';
import '../utils/signal_scheduling.dart';
// Gene - Nov, 7, 2026: Added AlarmScheduler and DatabaseService imports for active brew session persistence and background notification restoration.
import 'alarm_scheduler.dart';
import 'cue_player.dart';
import 'database_service.dart';

/// Owns the one running brew, decoupled from any screen.
///
/// `BrewRunScreen` borrows its controller from here instead of creating one,
/// so popping the screen no longer kills the brew: the clock, cues, and
/// wakelock live in the controller, and the controller lives here. The
/// floating chip in `MainNavigation` watches [active] to offer the way back.
class BrewSessionService {
  factory BrewSessionService() => _instance;

  BrewSessionService._internal();

  static final BrewSessionService _instance = BrewSessionService._internal();

  /// The controller of the current session, or null when there is none.
  final active = signal<BrewRunController?>(null);

  // Gene - Nov, 7, 2026: Cache injected dependencies so background lifecycle and notification-tap restoration use the same clock, cuePlayer, and scheduler.
  CuePlayer? _lastCuePlayer;
  AlarmScheduler? _lastScheduler;
  DateTime Function()? _lastClock;

  /// True while a brew has been started and has not finished — exactly the
  /// window in which the floater should be visible.
  bool get hasBrewInProgress {
    final controller = active.value;
    if (controller == null || controller.isFinished.value) {
      return false;
    }
    return controller.isRunning.value ||
        controller.elapsedInStepMs.value > 0 ||
        controller.stepIndex.value > 0;
  }

  /// The controller for [recipe] — the existing one when the session already
  /// runs this recipe (reopening resumes, never restarts), a fresh one
  /// otherwise. Starting a different recipe replaces the old session.
  // Gene - Nov, 7, 2026: Preserved original obtain, clear, and releaseIfIdle implementations.
  // BrewRunController obtain(BrewRecipe recipe, {CuePlayer? cuePlayer}) {
  //   final current = active.value;
  //   if (current != null && current.recipe.id == recipe.id) {
  //     return current;
  //   }
  //   clear();
  //   final controller = BrewRunController(recipe: recipe, cuePlayer: cuePlayer);
  //   setAfterBuild(active, controller);
  //   return controller;
  // }
  //
  // /// Ends the session: cancels the ticker, releases the wakelock, disposes
  // /// the cue player.
  // void clear() {
  //   active.value?.onClose();
  //   setAfterBuild(active, null);
  // }
  //
  // /// Called when the run screen is popped: a brew that was never started —
  // /// or has finished — has nothing worth floating, so let it go.
  // void releaseIfIdle() {
  //   if (!hasBrewInProgress) {
  //     clear();
  //   }
  // }

  // Gene - Nov, 7, 2026: Added scheduler/clock injection, Hive persistence, and syncOrRestore/restoreSessionIfActive for brew sessions.
  BrewRunController obtain(
    BrewRecipe recipe, {
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) {
    final current = active.value;
    if (current != null && current.recipe.id == recipe.id) {
      return current;
    }
    active.value?.onClose();
    _lastCuePlayer = cuePlayer;
    _lastScheduler = scheduler;
    _lastClock = clock;
    final controller = BrewRunController(
      recipe: recipe,
      cuePlayer: cuePlayer,
      scheduler: scheduler,
      clock: clock,
    );
    setAfterBuild(active, controller);
    return controller;
  }

  /// Ends the session: cancels the ticker, releases the wakelock, disposes
  /// the cue player.
  void clear() {
    active.value?.onClose();
    _lastCuePlayer = null;
    _lastScheduler = null;
    _lastClock = null;
    setAfterBuild(active, null);
    DatabaseService().clearActiveBrewSession();
  }

  /// Drops the in-memory controller while preserving the persisted Hive
  /// snapshot (simulating OS process eviction while backgrounded).
  void suspendInMemory() {
    active.value?.onClose();
    setAfterBuild(active, null);
  }

  Future<void> persistActiveSession() async {
    final current = active.value;
    if (current != null && hasBrewInProgress) {
      await current.persistSession();
    }
  }

  /// Called when the run screen is popped: a brew that was never started —
  /// or has finished — has nothing worth floating, so let it go.
  void releaseIfIdle() {
    if (active.value != null && !hasBrewInProgress) {
      clear();
    }
  }

  Future<BrewRunController?> syncOrRestore({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final current = active.value;
    if (current != null) {
      current.syncWithClock();
      if (current.isFinished.value) {
        clear();
        return null;
      }
      return current;
    }
    return restoreSessionIfActive(
      databaseService: databaseService,
      cuePlayer: cuePlayer ?? _lastCuePlayer,
      scheduler: scheduler ?? _lastScheduler,
      clock: clock ?? _lastClock,
    );
  }

  Future<BrewRunController?> restoreSessionIfActive({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final db = databaseService ?? DatabaseService();
    final data = await db.getActiveBrewSession();
    if (data == null) return null;

    final recipeId = data['recipeId'] as String?;
    if (recipeId == null) {
      await db.clearActiveBrewSession();
      return null;
    }

    BrewRecipe? recipe = await db.getBrewRecipe(recipeId);
    if (recipe == null && data['recipeJson'] is Map) {
      recipe = BrewRecipe.fromJson(
        Map<String, dynamic>.from(data['recipeJson'] as Map),
      );
    }
    if (recipe == null) {
      await db.clearActiveBrewSession();
      return null;
    }

    final controller = BrewRunController(
      recipe: recipe,
      cuePlayer: cuePlayer ?? _lastCuePlayer,
      scheduler: scheduler ?? _lastScheduler,
      clock: clock ?? _lastClock,
    );

    controller.restoreFromSnapshot(
      initialStepIndex: data['stepIndex'] as int? ?? 0,
      savedElapsedInStepMs: data['elapsedInStepMs'] as int? ?? 0,
      savedCarriedMs: data['carriedMs'] as int? ?? 0,
      stepStartedAtMs: data['stepStartedAtMs'] as int?,
      wasRunning: data['isRunning'] as bool? ?? false,
    );

    if (controller.isFinished.value) {
      await db.clearActiveBrewSession();
      return null;
    }

    setAfterBuild(active, controller);
    return controller;
  }
}
