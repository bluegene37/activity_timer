import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/activity_timer.dart';
import '../models/session_history.dart';
import '../services/database_service.dart';

class ActivityListController extends GetxController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final RxList<TimerSequence> sequences = <TimerSequence>[].obs;
  final RxList<SessionHistory> sessionHistory = <SessionHistory>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadSequences();
    loadSessionHistory();
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

  Future<void> loadSessionHistory() async {
    try {
      final history = await _databaseService.getSessionHistory();
      sessionHistory.assignAll(history);
    } catch (_) {}
  }

  Future<void> addPresetTemplate(TimerSequence template) async {
    final newSequence = TimerSequence(
      name: template.name,
      description: template.description,
      defaultLoopEnabled: template.defaultLoopEnabled,
      timers: template.timers
          .map((t) => ActivityTimer(
                name: t.name,
                durationInSeconds: t.durationInSeconds,
                description: t.description,
                alarmSoundName: t.alarmSoundName,
              ))
          .toList(),
    );

    try {
      await _databaseService.createActivitySequence(newSequence);
      sequences.add(newSequence);
      Get.snackbar('Success', 'Added "${newSequence.name}" preset');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add preset: $e');
    }
  }

  Future<void> addNewSequence() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final result = await Get.dialog<Map<String, String>>(
      AlertDialog(
        title: const Text('New Activity'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Activity Name',
                  hintText: 'Enter activity name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter description',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final desc = descriptionController.text.trim();
              Get.back(result: {
                'name': name.isNotEmpty ? name : 'New Activity',
                'description': desc,
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    // Give dialog time to animate out fully before disposing controllers to avoid exceptions
    await Future.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    descriptionController.dispose();

    if (result != null && result['name']!.isNotEmpty) {
      final newSequence = TimerSequence(
        name: result['name']!, 
        description: result['description']!.isEmpty ? null : result['description'],
        timers: []
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

  Future<void> editSequence(int index, String newName, String newDescription) async {
    if (newName.isEmpty) return;

    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: newName,
      description: newDescription.isEmpty ? null : newDescription,
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
      
      // Add slight delay to safely show snackbar
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Success', 'Activity deleted');
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to delete activity: $e');
    }
  }

  Future<void> toggleDefaultLoop(int index) async {
    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: sequence.name,
      description: sequence.description,
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
