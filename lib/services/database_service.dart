import 'dart:async';

import 'package:hive_ce/hive.dart';

import '../models/activity_timer.dart';
import '../models/brew_recipe.dart';
import '../models/interval_phase.dart';
import '../models/interval_timer.dart';
import '../models/session_history.dart';

class DatabaseService {
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();

  // Box names
  static const String _sequencesBoxName = 'activity_sequences';
  static const String _intervalTimersBoxName = 'interval_timers';
  static const String _historyBoxName = 'session_history';
  static const String _brewRecipesBoxName = 'brew_recipes';

  // `Hive.openBox` returns the already-open box on subsequent calls, so these
  // double as cheap accessors once `init()` has run.
  Future<Box<TimerSequence>> get _sequences =>
      Hive.openBox<TimerSequence>(_sequencesBoxName);
  Future<Box<IntervalTimer>> get _intervalTimers =>
      Hive.openBox<IntervalTimer>(_intervalTimersBoxName);
  Future<Box<SessionHistory>> get _history =>
      Hive.openBox<SessionHistory>(_historyBoxName);
  Future<Box<BrewRecipe>> get _brewRecipes =>
      Hive.openBox<BrewRecipe>(_brewRecipesBoxName);

  /// Open every box the app reads from.
  Future<void> init() async {
    await (_sequences, _intervalTimers, _history, _brewRecipes).wait;
  }

  // ACTIVITY SEQUENCE METHODS

  Future<List<TimerSequence>> getAllActivitySequences() async =>
      (await _sequences).values.toList();

  Future<TimerSequence?> getActivitySequence(String id) async =>
      (await _sequences).values
          .where((sequence) => sequence.id == id)
          .firstOrNull;

  Future<String> createActivitySequence(TimerSequence sequence) async {
    await (await _sequences).put(sequence.id, sequence);
    return sequence.id;
  }

  Future<void> updateActivitySequence(TimerSequence sequence) async {
    sequence.updatedAt = DateTime.now();
    await (await _sequences).put(sequence.id, sequence);
  }

  Future<void> deleteActivitySequence(String id) async =>
      (await _sequences).delete(id);

  /// Apply [change] to the stored sequence [sequenceId], then persist it with a
  /// refreshed `updatedAt`. Does nothing when the sequence no longer exists.
  Future<void> _editSequence(
    String sequenceId,
    void Function(TimerSequence sequence) change,
  ) async {
    final box = await _sequences;
    final sequence = box.values.where((s) => s.id == sequenceId).firstOrNull;
    if (sequence == null) return;

    change(sequence);
    sequence.updatedAt = DateTime.now();
    await box.put(sequenceId, sequence);
  }

  Future<void> addTimerToSequence(String sequenceId, ActivityTimer timer) =>
      _editSequence(sequenceId, (sequence) => sequence.timers.add(timer));

  Future<void> updateTimerInSequence(String sequenceId, ActivityTimer timer) =>
      _editSequence(sequenceId, (sequence) {
        final index = sequence.timers.indexWhere((t) => t.id == timer.id);
        if (index != -1) sequence.timers[index] = timer;
      });

  Future<void> deleteTimerFromSequence(String sequenceId, String timerId) =>
      _editSequence(
        sequenceId,
        (sequence) => sequence.timers.removeWhere((t) => t.id == timerId),
      );

  Future<void> reorderTimersInSequence(
    String sequenceId,
    List<String> timerIds,
  ) => _editSequence(sequenceId, (sequence) {
    final byId = {for (final timer in sequence.timers) timer.id: timer};
    sequence.timers = [
      for (final id in timerIds)
        if (byId[id] case final timer?) timer,
    ];
  });

  Future<TimerSequence?> duplicateSequence(String id) async {
    final box = await _sequences;
    final original = box.values.where((s) => s.id == id).firstOrNull;
    if (original == null) return null;

    final duplicate = TimerSequence(
      name: '${original.name} (Copy)',
      description: original.description,
      category: original.category,
      preparationSeconds: original.preparationSeconds,
      defaultLoopEnabled: original.defaultLoopEnabled,
      timers: [for (final timer in original.timers) timer.copyWith()],
    );

    await box.put(duplicate.id, duplicate);
    return duplicate;
  }

  // INTERVAL TIMER METHODS

  Future<List<IntervalTimer>> getAllIntervalTimers() async =>
      (await _intervalTimers).values.toList();

  Future<IntervalTimer?> getIntervalTimer(String id) async =>
      (await _intervalTimers).values
          .where((timer) => timer.id == id)
          .firstOrNull;

  Future<String> createIntervalTimer(IntervalTimer timer) async {
    await (await _intervalTimers).put(timer.id, timer);
    return timer.id;
  }

  Future<void> updateIntervalTimer(IntervalTimer timer) async {
    timer.updatedAt = DateTime.now();
    await (await _intervalTimers).put(timer.id, timer);
  }

  Future<void> deleteIntervalTimer(String id) async =>
      (await _intervalTimers).delete(id);

  // BREW RECIPE METHODS

  Future<List<BrewRecipe>> getAllBrewRecipes() async =>
      (await _brewRecipes).values.toList();

  Future<BrewRecipe?> getBrewRecipe(String id) async =>
      (await _brewRecipes).values
          .where((recipe) => recipe.id == id)
          .firstOrNull;

  Future<String> createBrewRecipe(BrewRecipe recipe) async {
    await (await _brewRecipes).put(recipe.id, recipe);
    return recipe.id;
  }

  Future<void> updateBrewRecipe(BrewRecipe recipe) async {
    recipe.updatedAt = DateTime.now();
    await (await _brewRecipes).put(recipe.id, recipe);
  }

  Future<void> deleteBrewRecipe(String id) async =>
      (await _brewRecipes).delete(id);

  // SESSION HISTORY METHODS

  Future<void> logSessionHistory(SessionHistory history) async =>
      (await _history).put(history.id, history);

  Future<List<SessionHistory>> getSessionHistory() async {
    final list = (await _history).values.toList();
    list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return list;
  }

  Future<void> clearSessionHistory() async => (await _history).clear();

  // PRESET TEMPLATE METHODS

  /// Built-in routines offered in the "Add preset" sheet.
  List<TimerSequence> getPresetTemplates({String? category}) {
    final all = [
      // ⚡ FITNESS PRESETS
      TimerSequence(
        name: 'Tabata HIIT (4 Min)',
        description: '8 rounds of 20s Max Effort + 10s Rest',
        category: 'fitness',
        preparationSeconds: 5,
        timers: [
          for (var round = 1; round <= 8; round++) ...[
            ActivityTimer(
              name: 'Work $round',
              durationInSeconds: 20,
              description: 'All-out effort',
            ),
            ActivityTimer(
              name: 'Rest $round',
              durationInSeconds: 10,
              phase: IntervalPhase.rest,
              description: 'Catch breath',
            ),
          ],
        ],
      ),
      TimerSequence(
        name: 'EMOM 10-Min',
        description: 'Every Minute On the Minute: 45s Work + 15s Transition',
        category: 'fitness',
        preparationSeconds: 5,
        timers: [
          for (var minute = 1; minute <= 10; minute++) ...[
            ActivityTimer(
              name: 'Minute $minute',
              durationInSeconds: 45,
              description: 'Complete target reps',
            ),
            ActivityTimer(
              name: 'Transition',
              durationInSeconds: 15,
              phase: IntervalPhase.rest,
              description: 'Prep next minute',
            ),
          ],
        ],
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
          for (final exercise in const [
            'Jumping Jacks',
            'Wall Sit',
            'Push-ups',
            'Abdominal Crunches',
            'Step-ups',
            'Squats',
            'Plank',
          ]) ...[
            ActivityTimer(name: exercise, durationInSeconds: 30),
            ActivityTimer(
              name: 'Rest',
              durationInSeconds: 10,
              phase: IntervalPhase.rest,
            ),
          ],
        ],
      ),
      TimerSequence(
        name: 'Run / Walk Cardio Intervals',
        description: '5 sets of 2m Jog/Run + 1m Walking Recovery',
        category: 'fitness',
        preparationSeconds: 5,
        timers: [
          for (var set = 1; set <= 5; set++) ...[
            ActivityTimer(
              name: 'Jog / Run',
              durationInSeconds: 120,
              description: 'Paced running',
            ),
            ActivityTimer(
              name: 'Walk Rest',
              durationInSeconds: 60,
              phase: IntervalPhase.rest,
              description: 'Active recovery walk',
            ),
          ],
        ],
      ),

      // 💼 WORK & PRODUCTIVITY PRESETS
      TimerSequence(
        name: 'Pomodoro 25/5 Classic',
        description: 'Deep focus blocks with structured short & long breaks',
        category: 'work',
        preparationSeconds: 3,
        timers: [
          for (var block = 1; block <= 4; block++) ...[
            ActivityTimer(
              name: 'Focus Block $block',
              durationInSeconds: 1500,
              description:
                  block == 4 ? 'Final focus block' : 'Deep focus on 1 task',
            ),
            if (block < 4)
              ActivityTimer(
                name: 'Short Break $block',
                durationInSeconds: 300,
                phase: IntervalPhase.rest,
                description: switch (block) {
                  1 => 'Stand up & drink water',
                  2 => 'Walk & stretch',
                  _ => 'Breathe & reset',
                },
              ),
          ],
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

  // BREW TEMPLATE METHODS

  /// Built-in pour-over recipes offered in the "Brew Library" sheet. These are
  /// code, not stored rows; the user clones one to get an editable copy.
  List<BrewRecipe> getBrewTemplates({BrewMethod? method}) {
    final all = [
      BrewRecipe(
        name: 'Hoffmann V60',
        method: BrewMethod.v60,
        doseGrams: 30,
        ratio: 16.67, // 30g x 16.67 = 500.1 -> 500g; 16.7 would give 501
        notes: 'James Hoffmann one-cup V60 technique.',
        steps: [
          BrewStep(
            name: 'Bloom',
            seconds: 45,
            pourToFraction: 0.12,
            pourSeconds: 10,
            description: 'Wet all the grounds, then swirl the slurry flat.',
          ),
          BrewStep(
            name: 'Second pour',
            seconds: 45,
            pourToFraction: 0.6,
            pourSeconds: 30,
            description: 'Steady spiral out from the centre.',
          ),
          BrewStep(
            name: 'Final pour',
            seconds: 30,
            pourToFraction: 1,
            pourSeconds: 30,
            description: 'Gentler now, keep the bed level.',
          ),
          BrewStep(name: 'Swirl', seconds: 10, kind: BrewStepKind.swirl),
          BrewStep(name: 'Drawdown', seconds: 95, kind: BrewStepKind.drawdown),
        ],
      ),
      BrewRecipe(
        name: 'Kasuya 4:6',
        method: BrewMethod.v60,
        doseGrams: 20,
        ratio: 15,
        notes:
            'Tetsu Kasuya 4:6 — first two pours set sweetness, last three set strength.',
        steps: [
          BrewStep(
            name: 'First pour',
            seconds: 45,
            pourToFraction: 0.2,
            pourSeconds: 10,
          ),
          BrewStep(
            name: 'Second pour',
            seconds: 45,
            pourToFraction: 0.4,
            pourSeconds: 10,
          ),
          BrewStep(
            name: 'Third pour',
            seconds: 45,
            pourToFraction: 0.6,
            pourSeconds: 10,
          ),
          BrewStep(
            name: 'Fourth pour',
            seconds: 45,
            pourToFraction: 0.8,
            pourSeconds: 10,
          ),
          BrewStep(
            name: 'Fifth pour',
            seconds: 45,
            pourToFraction: 1,
            pourSeconds: 10,
          ),
          BrewStep(name: 'Drawdown', seconds: 45, kind: BrewStepKind.drawdown),
        ],
      ),
      BrewRecipe(
        name: 'Chemex',
        method: BrewMethod.chemex,
        doseGrams: 30,
        ratio: 16.67,
        steps: [
          BrewStep(
            name: 'Bloom',
            seconds: 45,
            pourToFraction: 0.12,
            pourSeconds: 15,
          ),
          BrewStep(
            name: 'Second pour',
            seconds: 45,
            pourToFraction: 0.5,
            pourSeconds: 25,
          ),
          BrewStep(
            name: 'Third pour',
            seconds: 45,
            pourToFraction: 0.76,
            pourSeconds: 25,
          ),
          BrewStep(
            name: 'Final pour',
            seconds: 45,
            pourToFraction: 1,
            pourSeconds: 25,
          ),
          BrewStep(name: 'Drawdown', seconds: 90, kind: BrewStepKind.drawdown),
        ],
      ),
      BrewRecipe(
        name: 'Kalita Wave',
        method: BrewMethod.kalita,
        doseGrams: 20,
        ratio: 16,
        steps: [
          BrewStep(
            name: 'Bloom',
            seconds: 30,
            pourToFraction: 0.1875,
            pourSeconds: 10,
          ),
          BrewStep(
            name: 'Second pour',
            seconds: 30,
            pourToFraction: 0.5,
            pourSeconds: 15,
          ),
          BrewStep(
            name: 'Third pour',
            seconds: 30,
            pourToFraction: 0.75,
            pourSeconds: 15,
          ),
          BrewStep(
            name: 'Final pour',
            seconds: 30,
            pourToFraction: 1,
            pourSeconds: 15,
          ),
          BrewStep(name: 'Drawdown', seconds: 60, kind: BrewStepKind.drawdown),
        ],
      ),
      BrewRecipe(
        name: 'AeroPress',
        method: BrewMethod.aeropress,
        doseGrams: 11,
        ratio: 18.2,
        steps: [
          BrewStep(
            name: 'Pour',
            seconds: 15,
            pourToFraction: 1,
            pourSeconds: 15,
            description: 'Straight in, no bloom.',
          ),
          BrewStep(name: 'Steep', seconds: 120, kind: BrewStepKind.wait),
          BrewStep(name: 'Swirl', seconds: 10, kind: BrewStepKind.swirl),
          BrewStep(name: 'Settle', seconds: 30, kind: BrewStepKind.wait),
          BrewStep(
            name: 'Press',
            seconds: 30,
            kind: BrewStepKind.drawdown,
            description: 'Slow and even, stop at the hiss.',
          ),
        ],
      ),
    ];

    if (method == null) {
      return all;
    }
    return all.where((recipe) => recipe.method == method).toList();
  }

  /// Seed first-run demo content so the app never opens on an empty list.
  Future<void> insertDemoDataIfEmpty() async {
    final sequenceBox = await _sequences;
    if (sequenceBox.isEmpty) {
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

      final pomodoroActivity = TimerSequence(
        name: 'Pomodoro Focus Block',
        description: '25 min deep focus + 5 min break',
        category: 'work',
        preparationSeconds: 3,
        timers: [
          ActivityTimer(
            name: 'Deep Work',
            durationInSeconds: 1500,
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

      await sequenceBox.putAll({
        hiitActivity.id: hiitActivity,
        pomodoroActivity.id: pomodoroActivity,
      });
    }

    final intervalBox = await _intervalTimers;
    if (intervalBox.isEmpty) {
      // A workday timer: 8am to 5pm, alarm every hour.
      final now = DateTime.now();
      final workdayTimer = IntervalTimer(
        name: 'Hourly Boss Report / Standup',
        startTime: DateTime(now.year, now.month, now.day, 8),
        endTime: DateTime(now.year, now.month, now.day, 17),
        intervalValue: 1,
        intervalType: IntervalType.hour,
      );

      await intervalBox.put(workdayTimer.id, workdayTimer);
    }
  }

  /// Close all boxes.
  Future<void> closeBoxes() => Hive.close();
}
