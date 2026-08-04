import 'package:get/get.dart';
import '../models/activity_timer.dart';
import '../services/database_service.dart';
import '../screens/edit_timer_screen.dart';
import '../screens/timer_screen.dart';

class TimerListController extends GetxController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final Rx<TimerSequence> sequence = TimerSequence(name: '', timers: []).obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TimerSequence) {
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

  Future<void> addTimer() async {
    final newTimer = ActivityTimer(name: 'New Timer', durationInSeconds: 60);

    final result = await Get.to<ActivityTimer>(
      () => EditTimerScreen(timer: newTimer),
    );

    if (result != null) {
      try {
        // Optimistic update with a fresh list copy
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
          ..add(result);
        sequence.value = TimerSequence(
          id: sequence.value.id,
          name: sequence.value.name,
          description: sequence.value.description,
          timers: updatedTimers,
          defaultLoopEnabled: sequence.value.defaultLoopEnabled,
          createdAt: sequence.value.createdAt,
          updatedAt: DateTime.now(),
        );

        await _databaseService.addTimerToSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence(); // Revert on failure
        
        // Ensure no other navigation is active before showing snackbar
        await Future.delayed(const Duration(milliseconds: 100));
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
        // Optimistic update with a fresh list copy
        final updatedTimers = List<ActivityTimer>.from(sequence.value.timers);
        updatedTimers[index] = result;

        sequence.value = TimerSequence(
          id: sequence.value.id,
          name: sequence.value.name,
          description: sequence.value.description,
          timers: updatedTimers,
          defaultLoopEnabled: sequence.value.defaultLoopEnabled,
          createdAt: sequence.value.createdAt,
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateTimerInSequence(sequence.value.id, result);
      } catch (e) {
        await _reloadSequence(); // Revert on failure
        
        await Future.delayed(const Duration(milliseconds: 100));
        Get.snackbar('Error', 'Failed to update timer: $e');
      }
    }
  }

  Future<void> deleteTimer(int index) async {
    if (index < 0 || index >= sequence.value.timers.length) return;
    final timer = sequence.value.timers[index];

    try {
      // Optimistic update with a fresh list copy
      final updatedTimers = List<ActivityTimer>.from(sequence.value.timers)
        ..removeAt(index);
      sequence.value = TimerSequence(
        id: sequence.value.id,
        name: sequence.value.name,
        description: sequence.value.description,
        timers: updatedTimers,
        defaultLoopEnabled: sequence.value.defaultLoopEnabled,
        createdAt: sequence.value.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseService.deleteTimerFromSequence(
        sequence.value.id,
        timer.id,
      );
    } catch (e) {
      await _reloadSequence(); // Revert on failure
      
      await Future.delayed(const Duration(milliseconds: 100));
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

    // Optimistically update local state for smooth UI
    sequence.value = TimerSequence(
      id: sequence.value.id,
      name: sequence.value.name,
      description: sequence.value.description,
      timers: updatedTimers,
      defaultLoopEnabled: sequence.value.defaultLoopEnabled,
      createdAt: sequence.value.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      final timerIds = updatedTimers.map((t) => t.id).toList();
      await _databaseService.reorderTimersInSequence(
        sequence.value.id,
        timerIds,
      );
    } catch (e) {
      // Revert on error
      await _reloadSequence();
      
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to reorder timers: $e');
    }
  }

  Future<void> toggleDefaultLoop() async {
    final updatedSequence = TimerSequence(
      id: sequence.value.id,
      name: sequence.value.name,
      description: sequence.value.description,
      timers: sequence.value.timers,
      defaultLoopEnabled: !sequence.value.defaultLoopEnabled,
      createdAt: sequence.value.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.updateActivitySequence(updatedSequence);
      sequence.value = updatedSequence;
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to update loop setting: $e');
    }
  }

  void startTimerSequence() {
    if (sequence.value.timers.isEmpty) {
      Get.snackbar('Error', 'Add at least one timer to start the activity');
      return;
    }

    Get.to(() => TimerScreen(sequence: sequence.value));
  }

  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  String formatTotalDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final parts = <String>[];

    if (hours > 0) {
      parts.add('${hours}h');
    }

    if (minutes > 0 || (hours > 0 && seconds > 0)) {
      parts.add('${minutes}m');
    }

    if (seconds > 0 || parts.isEmpty) {
      parts.add('${seconds}s');
    }

    return parts.join(' ');
  }
}
