import 'package:hive_ce/hive.dart';
import '../models/interval_phase.dart';
import '../models/activity_timer.dart';
import '../models/interval_timer.dart';
import '../models/session_history.dart';

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
  static const String _historyBoxName = 'session_history';

  // Initialize Hive and register adapters
  Future<void> init() async {
    await Hive.openBox<TimerSequence>(_sequencesBoxName);
    await Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
    await Hive.openBox<SessionHistory>(_historyBoxName);
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

  // SESSION HISTORY METHODS

  Future<void> logSessionHistory(SessionHistory history) async {
    final box = await Hive.openBox<SessionHistory>(_historyBoxName);
    await box.put(history.id, history);
  }

  Future<List<SessionHistory>> getSessionHistory() async {
    final box = await Hive.openBox<SessionHistory>(_historyBoxName);
    final list = box.values.toList();
    list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return list;
  }

  Future<void> clearSessionHistory() async {
    final box = await Hive.openBox<SessionHistory>(_historyBoxName);
    await box.clear();
  }

  // Duplicate an activity sequence
  Future<TimerSequence?> duplicateSequence(String id) async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    final original = box.values.where((s) => s.id == id).firstOrNull;
    if (original == null) return null;

    final duplicate = TimerSequence(
      name: '${original.name} (Copy)',
      description: original.description,
      category: original.category,
      preparationSeconds: original.preparationSeconds,
      defaultLoopEnabled: original.defaultLoopEnabled,
      timers: original.timers.map((t) => t.copyWith()).toList(),
    );

    await box.put(duplicate.id, duplicate);
    return duplicate;
  }

  // PRESET TEMPLATE METHODS

  List<TimerSequence> getPresetTemplates({String? category}) {
    final all = [
      // ⚡ FITNESS PRESETS
      TimerSequence(
        name: 'Tabata HIIT (4 Min)',
        description: '8 rounds of 20s Max Effort + 10s Rest',
        category: 'fitness',
        preparationSeconds: 5,
        defaultLoopEnabled: false,
        timers: List.generate(
          8,
          (i) => [
            ActivityTimer(
              name: 'Work ${i + 1}',
              durationInSeconds: 20,
              phase: IntervalPhase.work,
              description: 'All-out effort',
            ),
            ActivityTimer(
              name: 'Rest ${i + 1}',
              durationInSeconds: 10,
              phase: IntervalPhase.rest,
              description: 'Catch breath',
            ),
          ],
        ).expand((e) => e).toList(),
      ),
      TimerSequence(
        name: 'EMOM 10-Min',
        description: 'Every Minute On the Minute: 45s Work + 15s Transition',
        category: 'fitness',
        preparationSeconds: 5,
        timers: List.generate(
          10,
          (i) => [
            ActivityTimer(
              name: 'Minute ${i + 1}',
              durationInSeconds: 45,
              phase: IntervalPhase.work,
              description: 'Complete target reps',
            ),
            ActivityTimer(
              name: 'Transition',
              durationInSeconds: 15,
              phase: IntervalPhase.rest,
              description: 'Prep next minute',
            ),
          ],
        ).expand((e) => e).toList(),
      ),
      TimerSequence(
        name: 'Boxing Sparring Rounds',
        description: '3 rounds of 3 min Sparring + 1 min Corner Rest',
        category: 'fitness',
        preparationSeconds: 10,
        timers: [
          ActivityTimer(
            name: 'Round 1',
            durationInSeconds: 180,
            phase: IntervalPhase.work,
            description: 'Punches & movement',
          ),
          ActivityTimer(
            name: 'Corner Rest 1',
            durationInSeconds: 60,
            phase: IntervalPhase.rest,
            description: 'Hydrate & recover',
          ),
          ActivityTimer(
            name: 'Round 2',
            durationInSeconds: 180,
            phase: IntervalPhase.work,
            description: 'Combinations & defense',
          ),
          ActivityTimer(
            name: 'Corner Rest 2',
            durationInSeconds: 60,
            phase: IntervalPhase.rest,
            description: 'Hydrate & recover',
          ),
          ActivityTimer(
            name: 'Round 3',
            durationInSeconds: 180,
            phase: IntervalPhase.work,
            description: 'Final round push',
          ),
          ActivityTimer(
            name: 'Cool Down',
            durationInSeconds: 120,
            phase: IntervalPhase.cooldown,
            description: 'Stretching & breathing',
          ),
        ],
      ),
      TimerSequence(
        name: '7-Minute Workout',
        description: 'Full body high-intensity circuit',
        category: 'fitness',
        preparationSeconds: 5,
        timers: [
          ActivityTimer(name: 'Jumping Jacks', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Wall Sit', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Push-ups', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Abdominal Crunches', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Step-ups', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Squats', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Plank', durationInSeconds: 30, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
        ],
      ),
      TimerSequence(
        name: 'Run / Walk Cardio Intervals',
        description: '5 sets of 2m Jog/Run + 1m Walking Recovery',
        category: 'fitness',
        preparationSeconds: 5,
        timers: List.generate(
          5,
          (i) => [
            ActivityTimer(
              name: 'Jog / Run',
              durationInSeconds: 120,
              phase: IntervalPhase.work,
              description: 'Paced running',
            ),
            ActivityTimer(
              name: 'Walk Rest',
              durationInSeconds: 60,
              phase: IntervalPhase.rest,
              description: 'Active recovery walk',
            ),
          ],
        ).expand((e) => e).toList(),
      ),

      // 💼 WORK & PRODUCTIVITY PRESETS
      TimerSequence(
        name: 'Pomodoro 25/5 Classic',
        description: 'Deep focus blocks with structured short & long breaks',
        category: 'work',
        preparationSeconds: 3,
        timers: [
          ActivityTimer(
            name: 'Focus Block 1',
            durationInSeconds: 1500,
            phase: IntervalPhase.work,
            description: 'Deep focus on 1 task',
          ),
          ActivityTimer(
            name: 'Short Break 1',
            durationInSeconds: 300,
            phase: IntervalPhase.rest,
            description: 'Stand up & drink water',
          ),
          ActivityTimer(
            name: 'Focus Block 2',
            durationInSeconds: 1500,
            phase: IntervalPhase.work,
            description: 'Deep focus on 1 task',
          ),
          ActivityTimer(
            name: 'Short Break 2',
            durationInSeconds: 300,
            phase: IntervalPhase.rest,
            description: 'Walk & stretch',
          ),
          ActivityTimer(
            name: 'Focus Block 3',
            durationInSeconds: 1500,
            phase: IntervalPhase.work,
            description: 'Deep focus on 1 task',
          ),
          ActivityTimer(
            name: 'Short Break 3',
            durationInSeconds: 300,
            phase: IntervalPhase.rest,
            description: 'Breathe & reset',
          ),
          ActivityTimer(
            name: 'Focus Block 4',
            durationInSeconds: 1500,
            phase: IntervalPhase.work,
            description: 'Final focus block',
          ),
          ActivityTimer(
            name: 'Long Break',
            durationInSeconds: 900,
            phase: IntervalPhase.rest,
            description: 'Full 15-min recovery break',
          ),
        ],
      ),
      TimerSequence(
        name: '50/10 Ultradian Focus',
        description: '50m High Concentration Sprint + 10m Complete Detach',
        category: 'work',
        preparationSeconds: 3,
        defaultLoopEnabled: true,
        timers: [
          ActivityTimer(
            name: 'Deep Work Block',
            durationInSeconds: 3000,
            phase: IntervalPhase.work,
            description: 'Uninterrupted creative/analytical flow',
          ),
          ActivityTimer(
            name: 'Rest & Detach',
            durationInSeconds: 600,
            phase: IntervalPhase.rest,
            description: 'Walk away from desk',
          ),
        ],
      ),
      TimerSequence(
        name: 'Stand & Hydrate Hourly',
        description: '55 min Desk Work + 5 min Physical Stretch & Water',
        category: 'work',
        preparationSeconds: 0,
        defaultLoopEnabled: true,
        timers: [
          ActivityTimer(
            name: 'Desk Work',
            durationInSeconds: 3300,
            phase: IntervalPhase.work,
            description: 'Focused task work',
          ),
          ActivityTimer(
            name: 'Stand & Hydrate',
            durationInSeconds: 300,
            phase: IntervalPhase.rest,
            description: 'Stand, hydrate, and stretch body',
          ),
        ],
      ),
      TimerSequence(
        name: '20-20-20 Eye Strain Reliever',
        description: '20 min screen work + 20 sec distance focus',
        category: 'work',
        preparationSeconds: 0,
        defaultLoopEnabled: true,
        timers: [
          ActivityTimer(
            name: 'Screen Work',
            durationInSeconds: 1200,
            phase: IntervalPhase.work,
            description: 'Working on screen',
          ),
          ActivityTimer(
            name: 'Gaze 20ft Away',
            durationInSeconds: 20,
            phase: IntervalPhase.rest,
            description: 'Look 20 feet away to relax eye muscles',
          ),
        ],
      ),
      TimerSequence(
        name: 'Box Breathing 4-4-4-4',
        description: 'Stress reduction & focus reset technique',
        category: 'work',
        preparationSeconds: 3,
        defaultLoopEnabled: true,
        timers: [
          ActivityTimer(
            name: 'Inhale',
            durationInSeconds: 4,
            phase: IntervalPhase.prepare,
            description: 'Inhale through nose',
          ),
          ActivityTimer(
            name: 'Hold In',
            durationInSeconds: 4,
            phase: IntervalPhase.work,
            description: 'Hold breath in lungs',
          ),
          ActivityTimer(
            name: 'Exhale',
            durationInSeconds: 4,
            phase: IntervalPhase.rest,
            description: 'Breathe out slowly',
          ),
          ActivityTimer(
            name: 'Hold Empty',
            durationInSeconds: 4,
            phase: IntervalPhase.cooldown,
            description: 'Hold with empty lungs',
          ),
        ],
      ),
    ];

    if (category == null || category == 'all') return all;
    return all.where((s) => s.category == category).toList();
  }

  // Insert demo data if the box is empty
  Future<void> insertDemoDataIfEmpty() async {
    final box = await Hive.openBox<TimerSequence>(_sequencesBoxName);
    if (box.isEmpty) {
      // HIIT Activity (Fitness)
      final hiitActivity = TimerSequence(
        name: 'HIIT Cardio Sprint',
        description: 'Cardio interval training',
        category: 'fitness',
        preparationSeconds: 5,
        timers: [
          ActivityTimer(
            name: 'Warm Up',
            durationInSeconds: 60,
            phase: IntervalPhase.prepare,
            description: 'Light jogging in place',
          ),
          ActivityTimer(
            name: 'High Intensity Sprint',
            durationInSeconds: 30,
            phase: IntervalPhase.work,
            description: 'Burpees / High Knees',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 15,
            phase: IntervalPhase.rest,
            description: 'Catch your breath',
          ),
          ActivityTimer(
            name: 'High Intensity Sprint',
            durationInSeconds: 30,
            phase: IntervalPhase.work,
            description: 'Mountain climbers',
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 15,
            phase: IntervalPhase.rest,
            description: 'Catch your breath',
          ),
          ActivityTimer(
            name: 'Cool Down',
            durationInSeconds: 60,
            phase: IntervalPhase.cooldown,
            description: 'Stretching',
          ),
        ],
      );

      // Pomodoro Work Activity
      final pomodoroActivity = TimerSequence(
        name: 'Pomodoro Focus Block',
        description: '25 min deep focus + 5 min break',
        category: 'work',
        preparationSeconds: 3,
        timers: [
          ActivityTimer(
            name: 'Deep Work',
            durationInSeconds: 1500,
            phase: IntervalPhase.work,
            description: 'Single task focus',
          ),
          ActivityTimer(
            name: 'Short Break',
            durationInSeconds: 300,
            phase: IntervalPhase.rest,
            description: 'Rest eyes and hydrate',
          ),
        ],
      );

      await box.put(hiitActivity.id, hiitActivity);
      await box.put(pomodoroActivity.id, pomodoroActivity);
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
        name: 'Hourly Boss Report / Standup',
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

