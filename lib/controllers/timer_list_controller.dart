import 'dart:async';

import 'package:signals/signals_flutter.dart';

import '../models/activity_timer.dart';
import '../models/interval_phase.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/ui_messenger.dart';
import '../utils/time_format.dart';

class TimerListController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final sequence = signal(TimerSequence(name: '', timers: []));

  void onInit() {}

  /// Points the controller at [incoming], which the route supplies.
  void load(TimerSequence incoming) {
    sequence.value = incoming;
  }

  Future<void> _reloadSequence() async {
    try {
      final updated = await _databaseService.getActivitySequence(
        sequence.value.id,
      );
      if (updated != null) {
        sequence.value = updated;
      }
    } catch (_) {}
  }

  Future<void> addTimer({IntervalPhase phase = IntervalPhase.work}) async {
    final newTimer = ActivityTimer(
      name: phase == IntervalPhase.rest ? 'Rest' : 'New Timer',
      durationInSeconds: phase == IntervalPhase.rest ? 15 : 45,
      phase: phase,
    );

    final result = await AppPages.push<ActivityTimer>(
      Routes.editTimer,
      extra: newTimer,
    );

    if (result != null) {
      try {
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
          ..add(result);
        _applyTimers(updatedTimers);

        await _databaseService.addTimerToSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        UiMessenger().showMessage('Failed to add timer: $e', title: 'Error');
      }
    }
  }

  Future<void> editTimer(int index) async {
    if (index < 0 || index >= sequence.value.timers.length) return;
    final timer = sequence.value.timers[index];

    final result = await AppPages.push<ActivityTimer>(
      Routes.editTimer,
      extra: timer,
    );

    if (result != null) {
      try {
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers);
        updatedTimers[index] = result;

        _applyTimers(updatedTimers);

        await _databaseService.updateTimerInSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        UiMessenger().showMessage('Failed to update timer: $e', title: 'Error');
      }
    }
  }

  Future<void> deleteTimer(int index) async {
    if (index < 0 || index >= sequence.value.timers.length) return;
    final timer = sequence.value.timers[index];

    try {
      final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
        ..removeAt(index);
      _applyTimers(updatedTimers);

      await _databaseService.deleteTimerFromSequence(
        sequence.value.id,
        timer.id,
      );
    } catch (e) {
      await _reloadSequence();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage('Failed to delete timer: $e', title: 'Error');
    }
  }

  Future<void> reorderTimers(int oldIndex, int newIndex) async {
    final timers = sequence.value.timers;
    if (oldIndex < 0 || oldIndex >= timers.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > timers.length) newIndex = timers.length;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final updatedTimers = List<ActivityTimer>.from(sequence.value.timers);
    final timer = updatedTimers.removeAt(oldIndex);
    updatedTimers.insert(newIndex, timer);

    _applyTimers(updatedTimers);

    try {
      final timerIds = updatedTimers.map((t) => t.id).toList();
      await _databaseService.reorderTimersInSequence(
        sequence.value.id,
        timerIds,
      );
    } catch (e) {
      await _reloadSequence();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage('Failed to reorder timers: $e', title: 'Error');
    }
  }

  /// Writes [updatedTimers] onto the routine every other holder already
  /// has a reference to, then tells the signal by force — the value is the
  /// same instance, so it would not notify on its own.
  void _applyTimers(List<ActivityTimer> updatedTimers) {
    final routine = sequence.value;
    routine.timers = updatedTimers;
    sequence.set(routine, force: true);
  }

  Future<void> toggleDefaultLoop() async {
    // Mutate the routine everything else already holds — the list that
    // handed it to this screen, and any live run session — rather than
    // swapping in a copy. A copy leaves those references on the old value,
    // so the next open loads the stale flag straight back over the change.
    final routine = sequence.value;
    routine.defaultLoopEnabled = !routine.defaultLoopEnabled;

    try {
      await _databaseService.updateActivitySequence(routine);
      // Same instance, so the signal needs telling explicitly.
      sequence.set(routine, force: true);
    } catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage(
        'Failed to update loop setting: $e',
        title: 'Error',
      );
    }
  }

  Future<void> updatePreparationSeconds(int seconds) async {
    final routine = sequence.value;
    routine.preparationSeconds = seconds;
    try {
      await _databaseService.updateActivitySequence(routine);
      sequence.set(routine, force: true);
      UiMessenger().showMessage(
        'Set lead-in to ${seconds}s',
        title: 'Prep Countdown',
      );
    } catch (e) {
      UiMessenger().showMessage(
        'Failed to update prep duration: $e',
        title: 'Error',
      );
    }
  }

  void startTimerSequence() {
    if (sequence.value.timers.isEmpty) {
      UiMessenger().showMessage(
        'Add at least one timer to start the activity',
        title: 'Error',
      );
      return;
    }

    unawaited(AppPages.push<void>(Routes.timer, extra: sequence.value));
  }

  String formatDuration(int seconds) => TimeFormat.clock(seconds);

  String formatTotalDuration(int totalSeconds) =>
      TimeFormat.compact(totalSeconds);
}
