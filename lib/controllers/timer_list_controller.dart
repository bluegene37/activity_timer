import 'package:get/get.dart';

import '../models/activity_timer.dart';
import '../models/interval_phase.dart';
import '../screens/edit_timer_screen.dart';
import '../screens/timer_screen.dart';
import '../services/database_service.dart';
import '../utils/time_format.dart';

class TimerListController extends GetxController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final Rx<TimerSequence> sequence = TimerSequence(name: '', timers: []).obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments case final TimerSequence args) {
      sequence.value = args;
    }
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

    final result = await Get.to<ActivityTimer>(
      () => EditTimerScreen(timer: newTimer, isNew: true),
    );

    if (result != null) {
      try {
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
          ..add(result);
        sequence.value = sequence.value.copyWith(timers: updatedTimers);

        await _databaseService.addTimerToSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        Get.snackbar('Error', 'Failed to add timer: $e');
      }
    }
  }

  Future<void> editTimer(int index) async {
    if (index < 0 || index >= sequence.value.timers.length) return;
    final timer = sequence.value.timers[index];

    final result = await Get.to<ActivityTimer>(
      () => EditTimerScreen(timer: timer),
    );

    if (result != null) {
      try {
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers);
        updatedTimers[index] = result;

        sequence.value = sequence.value.copyWith(timers: updatedTimers);

        await _databaseService.updateTimerInSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        Get.snackbar('Error', 'Failed to update timer: $e');
      }
    }
  }

  Future<void> deleteTimer(int index) async {
    if (index < 0 || index >= sequence.value.timers.length) return;
    final timer = sequence.value.timers[index];

    try {
      final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
        ..removeAt(index);
      sequence.value = sequence.value.copyWith(timers: updatedTimers);

      await _databaseService.deleteTimerFromSequence(
        sequence.value.id,
        timer.id,
      );
    } catch (e) {
      await _reloadSequence();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to delete timer: $e');
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

    sequence.value = sequence.value.copyWith(timers: updatedTimers);

    try {
      final timerIds = updatedTimers.map((t) => t.id).toList();
      await _databaseService.reorderTimersInSequence(
        sequence.value.id,
        timerIds,
      );
    } catch (e) {
      await _reloadSequence();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to reorder timers: $e');
    }
  }

  Future<void> toggleDefaultLoop() async {
    final updated = sequence.value.copyWith(
      defaultLoopEnabled: !sequence.value.defaultLoopEnabled,
    );

    try {
      await _databaseService.updateActivitySequence(updated);
      sequence.value = updated;
    } catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to update loop setting: $e');
    }
  }

  Future<void> updatePreparationSeconds(int seconds) async {
    final updated = sequence.value.copyWith(preparationSeconds: seconds);
    try {
      await _databaseService.updateActivitySequence(updated);
      sequence.value = updated;
      Get.snackbar('Prep Countdown', 'Set lead-in to ${seconds}s');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update prep duration: $e');
    }
  }

  void startTimerSequence() {
    if (sequence.value.timers.isEmpty) {
      Get.snackbar('Error', 'Add at least one timer to start the activity');
      return;
    }

    Get.to<void>(() => TimerScreen(sequence: sequence.value));
  }

  String formatDuration(int seconds) => TimeFormat.clock(seconds);

  String formatTotalDuration(int totalSeconds) =>
      TimeFormat.compact(totalSeconds);
}
