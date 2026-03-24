import 'package:hive_ce/hive.dart';
import '../models/activity_timer.dart';
import '../models/interval_timer.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // Box names
  static const String _sequencesBoxName = 'activity_sequences';
  static const String _intervalTimersBoxName = 'interval_timers';

  // Initialize Hive and register adapters
  Future<void> init() async {
    await Hive.openBox<TimerSequence>(_sequencesBoxName);
    await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
  }

  // Get all activity sequences
  Future<List<TimerSequence>> getAllActivitySequences() async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    return box.values.toList();
  }

  // Get an activity sequence by ID
  Future<TimerSequence?> getActivitySequence(String id) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    try {
      return box.values.firstWhere((sequence) => sequence.id == id);
    } catch (_) {
      return null;
    }
  }

  // Create a new activity sequence
  Future<String> createActivitySequence(TimerSequence sequence) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    await box.put(sequence.id, sequence);
    return sequence.id;
  }

  // Update an activity sequence
  Future<void> updateActivitySequence(TimerSequence sequence) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    sequence.updatedAt = DateTime.now();
    await box.put(sequence.id, sequence);
  }

  // Delete an activity sequence
  Future<void> deleteActivitySequence(String id) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    await box.delete(id);
  }

  // Add a timer to a sequence
  Future<void> addTimerToSequence(
    String sequenceId,
    ActivityTimer timer,
  ) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    try {
      final sequence = box.values.firstWhere((s) => s.id == sequenceId);
      sequence.timers.add(timer);
      sequence.updatedAt = DateTime.now();
      await box.put(sequenceId, sequence);
    } catch (_) {}
  }

  // Update a timer in a sequence
  Future<void> updateTimerInSequence(
    String sequenceId,
    ActivityTimer timer,
  ) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    try {
      final sequence = box.values.firstWhere((s) => s.id == sequenceId);
      final index = sequence.timers.indexWhere((t) => t.id == timer.id);
      if (index != -1) {
        sequence.timers[index] = timer;
        sequence.updatedAt = DateTime.now();
        await box.put(sequenceId, sequence);
      }
    } catch (_) {}
  }

  // Delete a timer from a sequence
  Future<void> deleteTimerFromSequence(
    String sequenceId,
    String timerId,
  ) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    try {
      final sequence = box.values.firstWhere((s) => s.id == sequenceId);
      sequence.timers.removeWhere((t) => t.id == timerId);
      sequence.updatedAt = DateTime.now();
      await box.put(sequenceId, sequence);
    } catch (_) {}
  }

  Future<void> reorderTimersInSequence(
    String sequenceId,
    List<String> timerIds,
  ) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    final sequence = box.values.where((s) => s.id == sequenceId).firstOrNull;

    if (sequence != null) {
      // Create a new ordered list of timers
      final orderedTimers = <ActivityTimer>[];
      for (final id in timerIds) {
        final timer = sequence.timers.where((t) => t.id == id).firstOrNull;
        if (timer != null) {
          orderedTimers.add(timer);
        }
      }

      sequence.timers = orderedTimers;
      sequence.updatedAt = DateTime.now();
      await box.put(sequenceId, sequence);
    }
  }

  // INTERVAL TIMER METHODS

  // Get all interval timers
  Future<List<IntervalTimer>> getAllIntervalTimers() async {
    final box = await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    return box.values.toList();
  }

  // Get an interval timer by ID
  Future<IntervalTimer?> getIntervalTimer(String id) async {
    final box = await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    try {
      return box.values.firstWhere((timer) => timer.id == id);
    } catch (_) {
      return null;
    }
  }

  // Create a new interval timer
  Future<String> createIntervalTimer(IntervalTimer timer) async {
    final box = await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    await box.put(timer.id, timer);
    return timer.id;
  }

  // Update an interval timer
  Future<void> updateIntervalTimer(IntervalTimer timer) async {
    final box = await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    timer.updatedAt = DateTime.now();
    await box.put(timer.id, timer);
  }

  // Delete an interval timer
  Future<void> deleteIntervalTimer(String id) async {
    final box = await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    await box.delete(id);
  }

  // Insert demo data if the box is empty
  Future<void> insertDemoDataIfEmpty() async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    if (box.isEmpty) {
      // HIIT Activity
      final hiitActivity = TimerSequence(
        name: 'HIIT Activity',
        description: 'Cardio Focus',
        timers: [
          ActivityTimer(
            name: 'Warm Up',
            durationInSeconds: 60,
            description: 'Light jogging in place',
          ),
          ActivityTimer(
            name: 'High Intensity',
            durationInSeconds: 30,
            description: 'Burpees',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 15,
            description: 'Catch your breath',
          ),
          ActivityTimer(
            name: 'High Intensity',
            durationInSeconds: 30,
            description: 'Mountain climbers',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 15,
            description: 'Catch your breath',
          ),
          ActivityTimer(
            name: 'Cool Down',
            durationInSeconds: 60,
            description: 'Stretching',
          ),
        ],
      );

      // Strength Training
      final strengthTraining = TimerSequence(
        name: 'Strength Activity',
        description: 'High Intensity',
        timers: [
          ActivityTimer(
            name: 'Warm Up',
            durationInSeconds: 120,
            description: 'Dynamic stretching',
          ),
          ActivityTimer(
            name: 'Squats',
            durationInSeconds: 45,
            description: '3 sets of 12 reps',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 60,
            description: 'Recovery',
          ),
          ActivityTimer(
            name: 'Bench Press',
            durationInSeconds: 45,
            description: '3 sets of 10 reps',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 60,
            description: 'Recovery',
          ),
          ActivityTimer(
            name: 'Cool Down',
            durationInSeconds: 120,
            description: 'Static stretching',
          ),
        ],
      );

      await box.put(hiitActivity.id, hiitActivity);
      await box.put(strengthTraining.id, strengthTraining);
    }

    // Add demo interval timer
    final intervalBox = await Hive.openBox<IntervalTimer>(
      _intervalTimersBoxName,
    );
    if (intervalBox.isEmpty) {
      // Create a workday timer (8am to 5pm, alarm every hour)
      final now = DateTime.now();
      final today8am = DateTime(now.year, now.month, now.day, 8, 0);
      final today5pm = DateTime(now.year, now.month, now.day, 17, 0);

      final workdayTimer = IntervalTimer(
        name: 'Workday Reminders',
        startTime: today8am,
        endTime: today5pm,
        intervalValue: 1,
        intervalType: IntervalType.hour,
      );

      await intervalBox.put(workdayTimer.id, workdayTimer);
    }
  }

  // Close all boxes
  Future<void> closeBoxes() async {
    await Hive.close();
  }
}
