import 'package:signals/signals.dart';

import '../controllers/interval_run_controller.dart';
import '../models/interval_timer.dart';
import '../utils/signal_scheduling.dart';
// Gene - Nov, 7, 2026: Added AlarmScheduler import for dependency injection and background restoration.
import 'alarm_scheduler.dart';
import 'cue_player.dart';
// Gene - Nov, 06, 2026: Added DatabaseService import for interval session persistence.
import 'database_service.dart';

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

  // Gene - Nov, 7, 2026: Cache injected dependencies so background lifecycle and notification-tap restoration use the same clock, cuePlayer, and scheduler.
  CuePlayer? _lastCuePlayer;
  AlarmScheduler? _lastScheduler;
  DateTime Function()? _lastClock;
  // Gene - Nov, 8, 2026: Guard against concurrent restoreSessionIfActive calls when notification tap and lifecycle resume fire simultaneously.
  Future<IntervalRunController?>? _restoreInFlight;

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
  // Gene - Nov, 06, 2026: Preserved original obtain and clear implementations.
  // IntervalRunController obtain(IntervalTimer timer, {CuePlayer? cuePlayer}) {
  //   final current = active.value;
  //   if (current != null && current.timer.id == timer.id) {
  //     return current;
  //   }
  //   clear();
  //   final controller = IntervalRunController(
  //     timer: timer,
  //     cuePlayer: cuePlayer,
  //   );
  //   // Nothing constructs controllers for us, so the service runs the
  //   // lifecycle hook screens rely on.
  //   controller.onInit();
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

  // Gene - Nov, 06, 2026: Persist interval session state and clear it on session end.
  // IntervalRunController obtain(IntervalTimer timer, {CuePlayer? cuePlayer}) {
  //   final current = active.value;
  //   if (current != null && current.timer.id == timer.id) {
  //     return current;
  //   }
  //   clear();
  //   final controller = IntervalRunController(
  //     timer: timer,
  //     cuePlayer: cuePlayer,
  //   );
  //   controller.onInit();
  //   setAfterBuild(active, controller);
  //   DatabaseService().saveActiveIntervalSession({
  //     'timerId': timer.id,
  //     'startedAtMs': DateTime.now().millisecondsSinceEpoch,
  //   });
  //   return controller;
  // }
  //
  // /// Ends the session: cancels the ticker, releases the wakelock, disposes
  // /// the cue player.
  // void clear() {
  //   active.value?.onClose();
  //   setAfterBuild(active, null);
  //   DatabaseService().clearActiveIntervalSession();
  // }
  //
  // /// Called when the run screen is popped: a completed schedule has nothing
  // /// worth floating, so let it go.
  // void releaseIfIdle() {
  //   if (!hasSessionInProgress) {
  //     clear();
  //   }
  // }
  //
  // // Gene - Nov, 06, 2026: Restores active interval session from DatabaseService on app relaunch.
  // Future<IntervalRunController?> restoreSessionIfActive({
  //   DatabaseService? databaseService,
  //   CuePlayer? cuePlayer,
  // }) async {
  //   final db = databaseService ?? DatabaseService();
  //   final data = await db.getActiveIntervalSession();
  //   if (data == null) return null;
  //
  //   final timerId = data['timerId'] as String?;
  //   if (timerId == null) {
  //     await db.clearActiveIntervalSession();
  //     return null;
  //   }
  //
  //   final timer = await db.getIntervalTimer(timerId);
  //   if (timer == null) {
  //     await db.clearActiveIntervalSession();
  //     return null;
  //   }
  //
  //   final controller = obtain(timer, cuePlayer: cuePlayer);
  //   if (controller.isCompleted.value) {
  //     clear();
  //     return null;
  //   }
  //   return controller;
  // }

  // Gene - Nov, 7, 2026: Added scheduler/clock injection, timerJson fallback persistence, and syncOrRestore/suspendInMemory lifecycle helpers for interval sessions.
  IntervalRunController obtain(
    IntervalTimer timer, {
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) {
    final current = active.value;
    if (current != null && current.timer.id == timer.id) {
      return current;
    }
    active.value?.onClose();
    _lastCuePlayer = cuePlayer;
    _lastScheduler = scheduler;
    _lastClock = clock;
    final controller = IntervalRunController(
      timer: timer,
      cuePlayer: cuePlayer,
      scheduler: scheduler,
      clock: clock,
    );
    controller.onInit();
    setAfterBuild(active, controller);
    final nowMs = (clock ?? DateTime.now)().millisecondsSinceEpoch;
    DatabaseService().saveActiveIntervalSession({
      'timerId': timer.id,
      'timerJson': timer.toJson(),
      'startedAtMs': nowMs,
    });
    return controller;
  }

  /// Ends the session: cancels the ticker, releases the wakelock, disposes
  /// the cue player.
  void clear() {
    active.value?.onClose();
    _lastCuePlayer = null;
    _lastScheduler = null;
    _lastClock = null;
    _restoreInFlight = null;
    setAfterBuild(active, null);
    DatabaseService().clearActiveIntervalSession();
  }

  /// Drops the in-memory controller while preserving the persisted Hive
  /// snapshot (simulating OS process eviction while backgrounded).
  void suspendInMemory() {
    active.value?.onClose();
    _restoreInFlight = null;
    setAfterBuild(active, null);
  }

  Future<void> persistActiveSession() async {
    final current = active.value;
    if (current != null && !current.isCompleted.value) {
      final nowMs = (_lastClock ?? DateTime.now)().millisecondsSinceEpoch;
      await DatabaseService().saveActiveIntervalSession({
        'timerId': current.timer.id,
        'timerJson': current.timer.toJson(),
        'startedAtMs': nowMs,
      });
    }
  }

  // Gene - Nov, 8, 2026: Suspend in-app periodic ticker when entering background so it never races with OS notifications.
  Future<void> onEnterBackground() async {
    final current = active.value;
    if (current != null && !current.isCompleted.value) {
      current.suspendTickerForBackground();
      await persistActiveSession();
    }
  }

  /// Called when the run screen is popped: a completed schedule has nothing
  /// worth floating, so let it go.
  void releaseIfIdle() {
    if (active.value != null && !hasSessionInProgress) {
      clear();
    }
  }

  Future<IntervalRunController?> syncOrRestore({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final current = active.value;
    if (current != null) {
      current.syncWithClock();
      if (current.isCompleted.value) {
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

  // Gene - Nov, 8, 2026: Deduplicate concurrent restoreSessionIfActive calls via _restoreInFlight so notification tap + app resume never spawn duplicate controllers.
  // Future<IntervalRunController?> restoreSessionIfActive({
  //   DatabaseService? databaseService,
  //   CuePlayer? cuePlayer,
  //   AlarmScheduler? scheduler,
  //   DateTime Function()? clock,
  // }) async {
  Future<IntervalRunController?> restoreSessionIfActive({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) {
    final inFlight = _restoreInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _doRestoreSessionIfActive(
      databaseService: databaseService,
      cuePlayer: cuePlayer,
      scheduler: scheduler,
      clock: clock,
    );
    _restoreInFlight = future;
    return future.whenComplete(() {
      if (identical(_restoreInFlight, future)) {
        _restoreInFlight = null;
      }
    });
  }

  Future<IntervalRunController?> _doRestoreSessionIfActive({
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final existing = active.value;
    if (existing != null) {
      existing.syncWithClock();
      if (existing.isCompleted.value) {
        clear();
        return null;
      }
      return existing;
    }
    final db = databaseService ?? DatabaseService();
    final data = await db.getActiveIntervalSession();
    if (data == null) return null;

    final timerId = data['timerId'] as String?;
    if (timerId == null) {
      await db.clearActiveIntervalSession();
      return null;
    }

    IntervalTimer? timer = await db.getIntervalTimer(timerId);
    if (timer == null && data['timerJson'] is Map) {
      timer = IntervalTimer.fromJson(
        Map<String, dynamic>.from(data['timerJson'] as Map),
      );
    }
    if (timer == null) {
      await db.clearActiveIntervalSession();
      return null;
    }

    final controller = obtain(
      timer,
      cuePlayer: cuePlayer ?? _lastCuePlayer,
      scheduler: scheduler ?? _lastScheduler,
      clock: clock ?? _lastClock,
    );
    if (controller.isCompleted.value) {
      clear();
      return null;
    }
    return controller;
  }

  // Gene - Nov, 8, 2026: Added snoozeActiveOrRestored() so tapping "Snooze 5m" on an OS notification re-arms the interval/time-alert schedule even if its final alarm just completed.
  Future<IntervalRunController?> snoozeActiveOrRestored(
    Duration duration, {
    DatabaseService? databaseService,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
  }) async {
    final existing = active.value;
    if (existing != null) {
      existing.snooze(duration);
      return existing;
    }

    final db = databaseService ?? DatabaseService();
    final data = await db.getActiveIntervalSession();
    if (data == null) {
      return null;
    }

    final timerId = data['timerId'] as String?;
    if (timerId == null) {
      return null;
    }

    IntervalTimer? timer = await db.getIntervalTimer(timerId);
    if (timer == null && data['timerJson'] is Map) {
      timer = IntervalTimer.fromJson(
        Map<String, dynamic>.from(data['timerJson'] as Map),
      );
    }
    if (timer == null) {
      return null;
    }

    final controller = obtain(
      timer,
      cuePlayer: cuePlayer ?? _lastCuePlayer,
      scheduler: scheduler ?? _lastScheduler,
      clock: clock ?? _lastClock,
    );
    controller.snooze(duration);
    return controller;
  }
}
