import 'package:signals/signals.dart';

import '../controllers/activity_run_controller.dart';
import '../models/activity_timer.dart';
import '../utils/signal_scheduling.dart';
import 'alarm_scheduler.dart';
import 'cue_player.dart';
import 'database_service.dart';

/// Owns the one running activity routine, decoupled from any screen.
///
/// `TimerScreen` borrows its controller from here instead of creating one, so
/// popping the screen minimizes the routine instead of killing it: the clock,
/// cues, and wakelock live in the controller, and the controller lives here.
/// The floating chip in `MainNavigation` watches [active] to offer the way
/// back.
class ActivitySessionService {
  factory ActivitySessionService() => _instance;

  ActivitySessionService._internal();

  static final ActivitySessionService _instance =
      ActivitySessionService._internal();

  /// The controller of the current session, or null when there is none.
  final active = signal<ActivityRunController?>(null);

  /// True while a routine is running or paused mid-way — exactly the window
  /// in which the floater should be visible. A routine starts the moment it
  /// is opened, so unlike a brew there is no "opened but never started"
  /// state to exclude.
  bool get hasSessionInProgress {
    final controller = active.value;
    return controller != null && !controller.isCompleted.value;
  }

  /// The controller for [sequence] — the existing one when the session
  /// already runs this routine (reopening resumes, never restarts), a fresh
  /// one otherwise. Starting a different routine replaces the old session.
  ActivityRunController obtain(TimerSequence sequence, {CuePlayer? cuePlayer}) {
    final current = active.value;
    if (current != null && current.sequence.id == sequence.id) {
      // The routine may have been edited elsewhere while this session was
      // minimized; pick up its saved preferences before handing it back.
      current.refreshFromSequence();
      return current;
    }
    clear();
    final controller = ActivityRunController(
      sequence: sequence,
      cuePlayer: cuePlayer,
    );
    // Nothing constructs controllers for us, so the service runs the
    // lifecycle hook screens rely on.
    controller.onInit();
    setAfterBuild(active, controller);
    return controller;
  }

  // Gene - Nov, 06, 2026: Preserved original clear implementation.
  // void clear() {
  //   active.value?.onClose();
  //   setAfterBuild(active, null);
  // }

  // Gene - Nov, 06, 2026: Clears in-memory controller and active session record in DatabaseService.
  void clear() {
    active.value?.onClose();
    setAfterBuild(active, null);
    DatabaseService().clearActiveActivitySession();
  }

  /// Called when the run screen is popped: a completed routine has nothing
  /// worth floating, so let it go.
  void releaseIfIdle() {
    if (!hasSessionInProgress) {
      clear();
    }
  }

  // Gene - Nov, 06, 2026: Restores active session from DatabaseService on cold-boot or app relaunch.
  Future<ActivityRunController?> restoreSessionIfActive({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final db = databaseService ?? DatabaseService();
    final data = await db.getActiveActivitySession();
    if (data == null) {
      return null;
    }

    final sequenceId = data['sequenceId'] as String?;
    if (sequenceId == null) {
      await db.clearActiveActivitySession();
      return null;
    }

    final sequence = await db.getActivitySequence(sequenceId);
    if (sequence == null) {
      await db.clearActiveActivitySession();
      return null;
    }

    final controller = ActivityRunController(
      sequence: sequence,
      cuePlayer: cuePlayer,
      scheduler: scheduler,
      clock: clock,
    );

    controller.restoreFromSnapshot(
      initialIndex: data['currentIndex'] as int? ?? 0,
      wasPreparing: data['isPreparing'] as bool? ?? false,
      wasRunning: data['isRunning'] as bool? ?? false,
      savedRemainingMs: data['remainingMs'] as int? ?? 0,
      deadlineMs: data['deadlineMs'] as int?,
      savedLoopEnabled:
          data['loopEnabled'] as bool? ?? sequence.defaultLoopEnabled,
      savedLoopCount: data['loopCount'] as int? ?? 0,
    );

    if (controller.isCompleted.value) {
      await db.clearActiveActivitySession();
      return null;
    }

    setAfterBuild(active, controller);
    return controller;
  }
}
