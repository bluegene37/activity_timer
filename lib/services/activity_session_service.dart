import 'package:signals/signals.dart';

import '../controllers/activity_run_controller.dart';
import '../models/activity_timer.dart';
import '../utils/signal_scheduling.dart';
import 'cue_player.dart';

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
      return current;
    }
    clear();
    final controller = ActivityRunController(
      sequence: sequence,
      cuePlayer: cuePlayer,
    );
    // Screens rely on onInit having run; GetxController only calls it when
    // registered, so trigger it explicitly for this service-owned instance.
    controller.onInit();
    setAfterBuild(active, controller);
    return controller;
  }

  /// Ends the session: cancels the ticker, releases the wakelock, disposes
  /// the cue player, and withdraws any pending background alarms.
  void clear() {
    active.value?.onClose();
    setAfterBuild(active, null);
  }

  /// Called when the run screen is popped: a completed routine has nothing
  /// worth floating, so let it go.
  void releaseIfIdle() {
    if (!hasSessionInProgress) {
      clear();
    }
  }
}
