import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/activity_timer.dart';
import '../models/session_history.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/ui_messenger.dart';
import '../utils/time_format.dart';

class ActivityListController extends GetxController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final RxList<TimerSequence> sequences = <TimerSequence>[].obs;
  final RxList<SessionHistory> sessionHistory = <SessionHistory>[].obs;
  final RxBool isLoading = true.obs;
  final RxString selectedCategory = 'all'.obs; // 'all', 'fitness', 'work'
  final RxString searchQuery = ''.obs;

  List<TimerSequence> get filteredSequences {
    return sequences.where((seq) {
      final matchesCategory =
          selectedCategory.value == 'all' ||
          seq.category.toLowerCase() == selectedCategory.value.toLowerCase();
      final query = searchQuery.value.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          seq.name.toLowerCase().contains(query) ||
          (seq.description != null &&
              seq.description!.toLowerCase().contains(query));
      return matchesCategory && matchesSearch;
    }).toList();
  }

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
      UiMessenger().showMessage(
        'Failed to load activities: $e',
        title: 'Error',
      );
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

  void setCategory(String category) {
    selectedCategory.value = category;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  Future<void> addPresetTemplate(TimerSequence template) async {
    final newSequence = TimerSequence(
      name: template.name,
      description: template.description,
      category: template.category,
      preparationSeconds: template.preparationSeconds,
      defaultLoopEnabled: template.defaultLoopEnabled,
      timers:
          template.timers
              .map(
                (t) => ActivityTimer(
                  name: t.name,
                  durationInSeconds: t.durationInSeconds,
                  description: t.description,
                  alarmSoundName: t.alarmSoundName,
                  phase: t.phase,
                ),
              )
              .toList(),
    );

    try {
      await _databaseService.createActivitySequence(newSequence);
      sequences.add(newSequence);
      UiMessenger().showMessage(
        'Added "${newSequence.name}" preset',
        title: 'Success',
      );
    } catch (e) {
      UiMessenger().showMessage('Failed to add preset: $e', title: 'Error');
    }
  }

  Future<void> duplicateSequence(int index) async {
    final original = sequences[index];
    try {
      final duplicate = await _databaseService.duplicateSequence(original.id);
      if (duplicate != null) {
        sequences.add(duplicate);
        UiMessenger().showMessage(
          'Duplicated "${original.name}"',
          title: 'Success',
        );
      }
    } catch (e) {
      UiMessenger().showMessage(
        'Failed to duplicate activity: $e',
        title: 'Error',
      );
    }
  }

  // JSON Serialization for Sharing
  static String sequenceToJson(TimerSequence sequence) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(sequence.toJson());
  }

  static TimerSequence? sequenceFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return TimerSequence.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> exportSequenceToClipboard(TimerSequence sequence) async {
    final jsonStr = sequenceToJson(sequence);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    UiMessenger().showMessage(
      'Routine "${sequence.name}" JSON copied to clipboard. '
      'Share it with anyone!',
      title: 'Exported to Clipboard',
    );
  }

  Future<bool> importSequenceFromJson(String jsonString) async {
    final sequence = sequenceFromJson(jsonString);
    if (sequence == null) {
      UiMessenger().showMessage(
        'Invalid timer routine JSON format.',
        title: 'Import Failed',
      );
      return false;
    }

    try {
      final newSequence = TimerSequence(
        name: sequence.name,
        description: sequence.description,
        category: sequence.category,
        preparationSeconds: sequence.preparationSeconds,
        defaultLoopEnabled: sequence.defaultLoopEnabled,
        timers: sequence.timers.map((t) => t.copyWith()).toList(),
      );

      await _databaseService.createActivitySequence(newSequence);
      sequences.add(newSequence);
      UiMessenger().showMessage(
        'Successfully added "${newSequence.name}" to your routines.',
        title: 'Imported!',
      );
      return true;
    } catch (e) {
      UiMessenger().showMessage('Failed to import routine: $e', title: 'Error');
      return false;
    }
  }

  Future<void> addNewSequence({
    String category = 'custom',
    int preparationSeconds = 5,
  }) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await UiMessenger()
        .showDialogBuilder<({String name, String description})>(
          (dialogContext) => AlertDialog(
            title: const Text('New Activity Routine'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Name',
                      hintText: 'e.g. HIIT Sprint, Pomodoro Focus',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. 5 rounds of high intensity',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  Navigator.pop(dialogContext, (
                    name: name.isNotEmpty ? name : 'New Activity',
                    description: descriptionController.text.trim(),
                  ));
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    descriptionController.dispose();

    if (result case (
      name: final name,
      description: final description,
    ) when name.isNotEmpty) {
      final newSequence = TimerSequence(
        name: name,
        description: description.isEmpty ? null : description,
        category: category,
        preparationSeconds: preparationSeconds,
        timers: [],
      );

      try {
        await _databaseService.createActivitySequence(newSequence);
        sequences.add(newSequence);

        unawaited(Get.toNamed<void>(Routes.timerList, arguments: newSequence));
      } catch (e) {
        UiMessenger().showMessage(
          'Failed to create activity: $e',
          title: 'Error',
        );
      }
    }
  }

  Future<void> editSequence(
    int index,
    String newName,
    String newDescription, {
    String? category,
    int? prepSeconds,
  }) async {
    if (newName.isEmpty) return;

    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: newName,
      description: newDescription.isEmpty ? null : newDescription,
      category: category ?? sequence.category,
      preparationSeconds: prepSeconds ?? sequence.preparationSeconds,
      timers: sequence.timers,
      defaultLoopEnabled: sequence.defaultLoopEnabled,
      createdAt: sequence.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.updateActivitySequence(updatedSequence);
      sequences[index] = updatedSequence;
    } catch (e) {
      UiMessenger().showMessage(
        'Failed to update activity: $e',
        title: 'Error',
      );
    }
  }

  Future<void> deleteSequence(int index) async {
    final sequence = sequences[index];

    try {
      await _databaseService.deleteActivitySequence(sequence.id);
      sequences.removeAt(index);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage('Activity deleted', title: 'Success');
    } catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage(
        'Failed to delete activity: $e',
        title: 'Error',
      );
    }
  }

  Future<void> toggleDefaultLoop(int index) async {
    final sequence = sequences[index];
    final updatedSequence = TimerSequence(
      id: sequence.id,
      name: sequence.name,
      description: sequence.description,
      category: sequence.category,
      preparationSeconds: sequence.preparationSeconds,
      timers: sequence.timers,
      defaultLoopEnabled: !sequence.defaultLoopEnabled,
      createdAt: sequence.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.updateActivitySequence(updatedSequence);
      sequences[index] = updatedSequence;
    } catch (e) {
      UiMessenger().showMessage(
        'Failed to update loop setting: $e',
        title: 'Error',
      );
    }
  }

  String formatTotalDuration(int totalSeconds) =>
      TimeFormat.compact(totalSeconds);
}
