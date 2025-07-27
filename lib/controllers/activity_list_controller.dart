import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/activity_timer.dart';
import '../services/database_service.dart';
import 'timer_list_controller.dart';

class ActivityListController extends GetxController {
  final _databaseService = DatabaseService();
  
  // Reactive variables
  final RxList<TimerSequence> sequences = <TimerSequence>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadSequences();
  }

  Future<void> loadSequences() async {
    isLoading.value = true;
    try {
      final loadedSequences = await _databaseService.getAllActivitySequences();
      sequences.assignAll(loadedSequences);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load activities: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addNewSequence() async {
    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('New Activity'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Activity Name',
            hintText: 'Enter activity name',
          ),
          autofocus: true,
          onSubmitted: (value) => Get.back(result: value),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'New Activity'),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newSequence = TimerSequence(
        name: result,
        timers: [],
      );

      try {
        await _databaseService.createActivitySequence(newSequence);
        sequences.add(newSequence);
        
        // Navigate to timer list for the new sequence
        Get.toNamed('/timer-list', arguments: newSequence);
      } catch (e) {
        Get.snackbar('Error', 'Failed to create activity: $e');
      }
    }
  }

  Future<void> editSequenceName(int index, String newName) async {
    if (newName.isEmpty) return;

    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: newName,
      timers: sequence.timers,
      defaultLoopEnabled: sequence.defaultLoopEnabled,
      createdAt: sequence.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.updateActivitySequence(updatedSequence);
      sequences[index] = updatedSequence;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update activity: $e');
    }
  }

  Future<void> deleteSequence(int index) async {
    final sequence = sequences[index];
    
    try {
      await _databaseService.deleteActivitySequence(sequence.id);
      sequences.removeAt(index);
      Get.snackbar('Success', 'Activity deleted');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete activity: $e');
    }
  }

  Future<void> toggleDefaultLoop(int index) async {
    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: sequence.name,
      timers: sequence.timers,
      defaultLoopEnabled: !sequence.defaultLoopEnabled,
      createdAt: sequence.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.updateActivitySequence(updatedSequence);
      sequences[index] = updatedSequence;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update loop setting: $e');
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