import 'package:signals/signals.dart';

import '../controllers/interval_run_controller.dart';
import '../models/interval_timer.dart';
import 'cue_player.dart';

/// Owns the one running interval session, decoupled from any screen.
///
/// `IntervalTimerScreen` borrows its controller from here instead of creating
/// one, so popping the screen minimizes the schedule instead of killing it:
/// the clock, cues, and wakelock live in the controller, and the controller
/// lives here. The floating chip in `MainNavigation` watches [active] to
/// offer the way back.
class IntervalSessionService {
  factory IntervalSessionService() => _instance;

  IntervalSessionService._internal();

  static final IntervalSessionService _instance =
      IntervalSessionService._internal();

  /// The controller of the current session, or null when there is none.
  final active = signal<IntervalRunController?>(null);

  /// True while an interval schedule is still ticking toward alarms —
  /// exactly the window in which the floater should be visible. (Interval
  /// sessions start the moment they are opened, so unlike a brew there is
  /// no "opened but never started" state.)
  bool get hasSessionInProgress {
    final controller = active.value;
    return controller != null && !controller.isCompleted.value;
  }

  /// The controller for [timer] — the existing one when the session already
  /// runs this timer (reopening resumes, never restarts), a fresh one
  /// otherwise. Starting a different timer replaces the old session.
  IntervalRunController obtain(IntervalTimer timer, {CuePlayer? cuePlayer}) {
    final current = active.value;
    if (current != null && current.timer.id == timer.id) {
      return current;
    }
    clear();
    final controller = IntervalRunController(
      timer: timer,
      cuePlayer: cuePlayer,
    );
    // Screens rely on onInit having run; GetxController only calls it when
    // registered, so trigger it explicitly for this service-owned instance.
    controller.onInit();
    active.value = controller;
    return controller;
  }

  /// Ends the session: cancels the ticker, releases the wakelock, disposes
  /// the cue player.
  void clear() {
    active.value?.onClose();
    active.value = null;
  }

  /// Called when the run screen is popped: a completed schedule has nothing
  /// worth floating, so let it go.
  void releaseIfIdle() {
    if (!hasSessionInProgress) {
      clear();
    }
  }
}
