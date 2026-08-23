# Activity Timer Modernization & Dual-Mode Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Activity Timer into a production-ready, modern timer for athletes (workouts, intervals, run/rest) and workers (hourly supervisor check-ins, Pomodoro focus) on iOS and Android.

**Architecture:** Extend Hive domain models with `IntervalPhase` (work, rest, prep, cooldown), category tags, and preparation countdowns. Implement responsive portrait and landscape HUD layouts with phase-reactive glowing rings, live in-session +/-15s adjustments, audio/haptic phase transition cues, workplace check-in presets, JSON sharing/duplication, and wall-clock drift compensation.

**Tech Stack:** Flutter 3.7+, Dart 3.7+, Hive CE, GetX, audioplayers, wakelock_plus, intl, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-23-activity-timer-modernization-design.md`

## Global Constraints
- Target Platforms: iOS and Android
- State Management: GetX
- Database: Hive CE (backward-compatible, no data wipe)
- Linter: Zero errors under `flutter_lints: ^6.0.0`
- Tests: All unit and widget tests must pass cleanly

---

### Task 1: Domain Models & Hive Adapters

**Files:**
- Create: `lib/models/interval_phase.dart`
- Modify: `lib/models/activity_timer.dart`
- Modify: `lib/models/interval_timer.dart`
- Modify: `lib/models/session_history.dart`
- Modify: `lib/main.dart:15-35`
- Test: `test/models_test.dart`

**Interfaces:**
- Produces: `IntervalPhase` enum (`work`, `rest`, `prepare`, `cooldown`).
- Produces: `ActivityTimer.phase` (`IntervalPhase`), `TimerSequence.category` (`String`), `TimerSequence.preparationSeconds` (`int`).
- Produces: `SessionHistory.category` (`String`).

- [ ] **Step 1: Write the failing unit tests for extended models**

```dart
// test/models_test.dart additions
test('ActivityTimer supports phase property and default is work', () {
  final timer = ActivityTimer(name: 'Sprint', durationInSeconds: 30, phase: IntervalPhase.work);
  expect(timer.phase, IntervalPhase.work);
  expect(timer.isWork, true);
  expect(timer.isRest, false);

  final restTimer = timer.copyWith(phase: IntervalPhase.rest);
  expect(restTimer.phase, IntervalPhase.rest);
  expect(restTimer.isRest, true);
});

test('TimerSequence supports category and preparationSeconds', () {
  final seq = TimerSequence(
    name: 'HIIT',
    timers: [ActivityTimer(name: 'Run', durationInSeconds: 60)],
    category: 'fitness',
    preparationSeconds: 5,
  );
  expect(seq.category, 'fitness');
  expect(seq.preparationSeconds, 5);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models_test.dart`  
Expected: FAIL (IntervalPhase, phase, category, preparationSeconds not defined).

- [ ] **Step 3: Implement `IntervalPhase` and update models**

Create `lib/models/interval_phase.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

part 'interval_phase.g.dart';

@HiveType(typeId: 7)
enum IntervalPhase {
  @HiveField(0)
  work,
  @HiveField(1)
  rest,
  @HiveField(2)
  prepare,
  @HiveField(3)
  cooldown;

  String get displayName {
    switch (this) {
      case IntervalPhase.work:
        return 'Work';
      case IntervalPhase.rest:
        return 'Rest';
      case IntervalPhase.prepare:
        return 'Prepare';
      case IntervalPhase.cooldown:
        return 'Cool Down';
    }
  }

  IconData get icon {
    switch (this) {
      case IntervalPhase.work:
        return Icons.fitness_center;
      case IntervalPhase.rest:
        return Icons.bedtime_outlined;
      case IntervalPhase.prepare:
        return Icons.hourglass_top_outlined;
      case IntervalPhase.cooldown:
        return Icons.ac_unit;
    }
  }

  Color get defaultColor {
    switch (this) {
      case IntervalPhase.work:
        return const Color(0xFFFF6D00); // Energetic amber/orange
      case IntervalPhase.rest:
        return const Color(0xFF00B0FF); // Calming cyan/blue
      case IntervalPhase.prepare:
        return const Color(0xFFFFD600); // Golden yellow
      case IntervalPhase.cooldown:
        return const Color(0xFF00E676); // Fresh mint green
    }
  }
}
```

Update `lib/models/activity_timer.dart`, `lib/models/session_history.dart`, and run `dart run build_runner build --delete-conflicting-outputs`.  
Register `IntervalPhaseAdapter` in `lib/main.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/ lib/main.dart test/models_test.dart
git commit -m "feat: add IntervalPhase enum and extend ActivityTimer and TimerSequence models"
```

---

### Task 2: Specialized Built-in Presets for Fitness & Work

**Files:**
- Modify: `lib/services/database_service.dart:185-350`
- Test: `test/preset_templates_test.dart`

**Interfaces:**
- Produces: `DatabaseService.getPresetTemplates({String? category})` returning rich templates categorized by `'fitness'` and `'work'`.

- [ ] **Step 1: Write the failing tests for categorized presets**

```dart
// test/preset_templates_test.dart
test('getPresetTemplates returns fitness and work presets with correct phases', () {
  final db = DatabaseService();
  final presets = db.getPresetTemplates();
  expect(presets.any((p) => p.category == 'fitness'), true);
  expect(presets.any((p) => p.category == 'work'), true);

  final tabata = presets.firstWhere((p) => p.name.contains('Tabata'));
  expect(tabata.timers.any((t) => t.phase == IntervalPhase.work), true);
  expect(tabata.timers.any((t) => t.phase == IntervalPhase.rest), true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/preset_templates_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement comprehensive presets in `DatabaseService`**

Add presets: Tabata (4m), EMOM 10m, Boxing 3-Min Rounds, 7-Minute Workout, Run-Walk, Pomodoro 25/5, 50/10 Deep Work, Stand & Hydrate, 20-20-20 Eye Rest, Hourly Boss Report.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/preset_templates_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/database_service.dart test/preset_templates_test.dart
git commit -m "feat: add comprehensive fitness and workplace presets with phase awareness"
```

---

### Task 3: Routine Duplication & JSON Import / Export

**Files:**
- Modify: `lib/services/database_service.dart`
- Modify: `lib/controllers/activity_list_controller.dart`
- Test: `test/routine_sharing_test.dart`

**Interfaces:**
- Produces: `DatabaseService.duplicateSequence(String id)`
- Produces: `ActivityListController.exportSequenceJson(TimerSequence sequence)` -> `String`
- Produces: `ActivityListController.importSequenceJson(String jsonString)` -> `bool`

- [ ] **Step 1: Write failing unit test for duplicate & JSON export/import**

```dart
test('exports and imports TimerSequence to and from JSON', () {
  final original = TimerSequence(
    name: 'Boxing Sparring',
    category: 'fitness',
    preparationSeconds: 5,
    timers: [
      ActivityTimer(name: 'Round 1', durationInSeconds: 180, phase: IntervalPhase.work),
      ActivityTimer(name: 'Rest', durationInSeconds: 60, phase: IntervalPhase.rest),
    ],
  );

  final jsonStr = ActivityListController.sequenceToJson(original);
  final imported = ActivityListController.sequenceFromJson(jsonStr);

  expect(imported?.name, 'Boxing Sparring');
  expect(imported?.category, 'fitness');
  expect(imported?.timers.length, 2);
  expect(imported?.timers[0].phase, IntervalPhase.work);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/routine_sharing_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement JSON serializer and duplication logic**

Add JSON serialize/deserialize with error handling and database duplication methods.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/routine_sharing_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ lib/controllers/ test/routine_sharing_test.dart
git commit -m "feat: add routine duplication and JSON import/export sharing"
```

---

### Task 4: Active Timer HUD Engine & Live In-Session Controls

**Files:**
- Modify: `lib/screens/timer_screen.dart`
- Modify: `lib/components/glowing_timer_ring.dart`
- Test: `test/timer_screen_test.dart`

**Interfaces:**
- Produces: Phase-reactive glowing ring color, preparation countdown state (`_isPreparing`), `_addTime(int seconds)` live adjustments (+15s / -15s), 3-2-1 audio & haptic cues.

- [ ] **Step 1: Write test for preparation countdown and live time adjustments**

```dart
testWidgets('TimerScreen handles preparation countdown then starts first timer', (tester) async {
  final seq = TimerSequence(
    name: 'Sprint Session',
    preparationSeconds: 3,
    timers: [ActivityTimer(name: 'Sprint', durationInSeconds: 10, phase: IntervalPhase.work)],
  );
  await tester.pumpWidget(MaterialApp(home: TimerScreen(sequence: seq)));
  expect(find.textContaining('GET READY', findRichText: true), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/timer_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement preparation countdown, live +/-15s adjustments, and phase-aware alarms**

Implement in `lib/screens/timer_screen.dart`:
- Lead-in preparation countdown (3s, 5s, 10s or 0s) before sequence starts.
- Live `+15s` and `-15s` adjustments modifying `_deadline` without resetting.
- Phase-dependent color palette (Work, Rest, Prepare, Cooldown).
- Phase transition audio beeps & haptic feedback.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/timer_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/timer_screen.dart lib/components/glowing_timer_ring.dart test/timer_screen_test.dart
git commit -m "feat: implement preparation countdown, phase-reactive alerts, and live +/-15s controls"
```

---

### Task 5: Responsive Fullscreen Landscape HUD

**Files:**
- Modify: `lib/screens/timer_screen.dart`
- Test: `test/landscape_timer_test.dart`

**Interfaces:**
- Produces: Automatic switch between Portrait View and Split-Screen Fullscreen Landscape HUD when device orientation changes.

- [ ] **Step 1: Write widget test for landscape mode rendering**

```dart
testWidgets('TimerScreen renders landscape HUD when orientation is horizontal', (tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final seq = TimerSequence(
    name: 'Gym Workout',
    timers: [ActivityTimer(name: 'Work', durationInSeconds: 30, phase: IntervalPhase.work)],
  );
  await tester.pumpWidget(MaterialApp(home: TimerScreen(sequence: seq)));
  await tester.pumpAndSettle();

  expect(find.text('Gym Workout'), findsWidgets);
  expect(find.byIcon(Icons.play_arrow), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/landscape_timer_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement responsive layout using `OrientationBuilder`**

Build `_buildLandscapeLayout` and `_buildPortraitLayout` inside `TimerScreen` with massive tabular digits (80pt+) on the left and oversized touch controls on the right.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/landscape_timer_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/timer_screen.dart test/landscape_timer_test.dart
git commit -m "feat: add fullscreen landscape HUD with high-contrast oversized display"
```

---

### Task 6: Modernized Home Dashboard with Category Hub

**Files:**
- Modify: `lib/screens/activity_list_screen.dart`
- Modify: `lib/controllers/activity_list_controller.dart`
- Test: `test/activity_list_screen_test.dart`

**Interfaces:**
- Produces: Category filter bar (`All`, `Fitness`, `Work`), search filter, step phase badge previews, duplicate/export/import dialogs.

- [ ] **Step 1: Write widget tests for category filter and quick actions**

```dart
testWidgets('ActivityListScreen filters routines by category and shows presets bottom sheet', (tester) async {
  // Test category filtering and preset browsing
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/activity_list_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Update `ActivityListScreen` and `ActivityListController`**

Add category chip bar, search text field, enhanced card with phase icons, 1-click duplicate, export/import JSON bottom sheet, and categorized preset picker.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/activity_list_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/activity_list_screen.dart lib/controllers/activity_list_controller.dart test/activity_list_screen_test.dart
git commit -m "feat: upgrade activity list screen with category tabs, search, and routine sharing"
```

---

### Task 7: Interval Timers & Workplace Periodic Check-ins

**Files:**
- Modify: `lib/screens/interval_timer_list_screen.dart`
- Modify: `lib/screens/edit_interval_timer_screen.dart`
- Modify: `lib/screens/interval_timer_screen.dart`
- Test: `test/interval_timer_test.dart`

**Interfaces:**
- Produces: 1-click workplace presets ("Hourly Boss Check-in", "2-Hour Status Report"), time picker refinements, alarm timeline preview.

- [ ] **Step 1: Write test for interval timer workplace check-ins**

```dart
testWidgets('IntervalTimerListScreen displays periodic check-in templates', (tester) async {
  // Test check-in templates and interval calculation
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/interval_timer_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement workplace check-in templates and timeline UX**

Add 1-click hourly/bi-hourly work check-in presets, clean interval timeline pills, and sound preview.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/interval_timer_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/interval_timer_list_screen.dart lib/screens/edit_interval_timer_screen.dart lib/screens/interval_timer_screen.dart test/interval_timer_test.dart
git commit -m "feat: enhance interval timer with workplace boss check-in presets and timeline view"
```

---

### Task 8: Orientation Enablement, Full System Verification & Production Polish

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/theme/app_theme.dart`
- Test: All tests in `test/`

**Interfaces:**
- Enables `portraitUp`, `portraitDown`, `landscapeLeft`, `landscapeRight`.
- Verifies zero linter warnings and 100% test pass.

- [ ] **Step 1: Update orientations in `lib/main.dart`**

```dart
SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
```

- [ ] **Step 2: Run full test suite**

Run: `flutter test`  
Expected: ALL PASS.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`  
Expected: "No issues found!".

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/theme/
git commit -m "chore: enable multi-orientation and finalize production polish"
```
