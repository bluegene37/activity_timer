# Activity Timer UX/UI Modernization & Feature Upgrade — Design Specification

**Date:** 2026-08-23  
**Status:** Approved by User  
**Target Platforms:** iOS & Android (Flutter 3.7+ / Dart 3.7+)

---

## 1. Overview & Objectives

The goal is to upgrade **Activity Timer** into a modern, industry-standard, production-ready timer application tailored for both **Athletes (workouts, intervals, run/rest routines)** and **Workers (workplace check-ins, hourly reports to supervisors, Pomodoro focus blocks)**.

### Key Value Propositions
1. **Athletic & Fitness Workouts**:
   - Customizable sequential intervals with explicit **Work / Rest / Prepare / Cooldown** phases.
   - Distinct, glanceable color changes and audio/haptic cues so athletes know when to run and when to rest without needing to look at their phone.
   - Lead-in **Preparation Countdown** (3s/5s/10s) before routines start.
   - Responsive **Landscape HUD Mode** with giant digits for gym equipment and floor racks.
   - Quick **`+15s` / `-15s`** live adjustment buttons during active sessions.
   - Preset templates: Tabata (4m), EMOM (10m), Boxing Sparring Rounds, 7-Minute Workout, Run-Walk intervals.

2. **Workplace & Productivity Management**:
   - Reliable **Interval & Periodic Check-in Timers** for employees required to report or call their manager every 1 hour, 2 hours, or specific shift times (e.g. 9am, 11am, 1pm, 3pm, 5pm).
   - Loud, unmistakable alarm tones with sound previews.
   - Presets for Hourly Boss Reports, 2-Hour Status Checks, Pomodoro 25/5, 50/10 Deep Work, Stand & Hydrate, and 20-20-20 Eye Strain Reliever.

3. **Modern UX & Production Standards**:
   - Modern Material 3 / iOS design system with dynamic theme modes (Dark, Light, System) and custom accent colors.
   - Category filtering on home screen (**All**, **⚡ Fitness & Sports**, **💼 Work & Focus**).
   - Routine duplication, JSON Export/Import for routine sharing, and Reorderable timer steps.
   - Wall-clock drift compensation with background resumption and active screen wakelock.
   - Full orientation support (Portrait & Landscape).

---

## 2. Architecture & Data Model Changes

### 2.1 Enums & Data Classes

#### `IntervalPhase` (New Hive Type)
```dart
@HiveType(typeId: 7)
enum IntervalPhase {
  @HiveField(0)
  work,
  @HiveField(1)
  rest,
  @HiveField(2)
  prepare,
  @HiveField(3)
  cooldown,
}
```

#### `ActivityTimer` (Enhanced)
- `String id`
- `String name`
- `int durationInSeconds`
- `String? description`
- `String? alarmSoundName`
- `IntervalPhase phase` (defaults to `IntervalPhase.work`)

#### `TimerSequence` (Enhanced)
- `String id`
- `String name`
- `List<ActivityTimer> timers`
- `bool defaultLoopEnabled`
- `String category` (`'fitness'`, `'work'`, or `'custom'`)
- `int preparationSeconds` (0, 3, 5, or 10 seconds lead-in, default `5`)
- `DateTime createdAt`
- `DateTime updatedAt`
- `String? description`

#### `SessionHistory` (Enhanced)
- `String id`
- `String title`
- `DateTime completedAt`
- `int totalDurationInSeconds`
- `int itemCount`
- `int loopCount`
- `String sessionType` (`'activity'` or `'interval'`)
- `String category` (`'fitness'`, `'work'`)

---

## 3. UI/UX Specifications

### 3.1 Home Dashboard (`ActivityListScreen`)
- **Top Header**: App icon, title, subtitle, stats/history icon button, JSON import button.
- **Category Filter Chips**: Segmented / filter bar with `All`, `⚡ Fitness`, `💼 Work`.
- **Search & Quick Actions**: Search by routine name.
- **Routine Cards**:
  - Category pill (`Fitness` / `Work`), Total duration, Step count, Loop badge.
  - Step breakdown preview (e.g. `🔥 45s Work` • `☕ 15s Rest`).
  - Action buttons: Start Routine, Edit, Duplicate, Share/Export JSON, Delete.
- **Empty State**: Friendly illustration and direct "Explore Presets" button.
- **Floating Action Button**: "+ Create Routine".

### 3.2 Active Timer HUD (`TimerScreen`)
- **Orientation Awareness**:
  - **Portrait HUD**:
    - Top Bar: Close confirmation, Sound Mute/Unmute toggle, Loop toggle, Phase badge.
    - Overall Sequence Progress Bar.
    - Large Glowing Ring with phase-reactive color and smooth animation:
      - Work: Energetic Amber / Lime / User Accent
      - Rest: Cool Cyan / Indigo
      - Prepare: Golden Yellow / Violet
      - Cooldown: Calming Teal / Blue
    - Tabular Figures Clock Display (e.g. `00:45`).
    - Quick In-Session Controls: `+15s`, `-15s`, Next step, Prev step.
    - Next-Up Preview Card with phase icon and duration.
    - Large tactile Play/Pause FAB.
  - **Landscape Fullscreen HUD (Gym & Desk Mounts)**:
    - Left side (60% width): Massive, high-contrast digital clock (90pt+), big Phase Banner, and circular/linear elapsed progress.
    - Right side (40% width): Next-Up step card, loop counter, and oversized touch controls (Play/Pause, `+15s`, `-15s`, Next, Prev, Reset).
- **Audio & Haptics**:
  - 3-2-1 countdown ticks during the last 3 seconds.
  - Distinct Work transition alarm vs. Rest transition alarm.
  - Haptic feedback pattern (strong double pulse on Work start, gentle pulse on Rest start).

### 3.3 Interval Timers & Scheduled Check-ins (`IntervalTimerListScreen` & `IntervalTimerScreen`)
- Built-in Workplace Check-in Presets:
  - *Hourly Boss Check-in / Standup Report* (8:00 AM – 5:00 PM, every 1 hr)
  - *Bi-Hourly Status Report* (9:00 AM – 5:00 PM, every 2 hrs)
  - *Custom Shift Reminder* (Set start, end, and 15m/30m/1h/2h intervals).
- Real-time countdown to the next scheduled check-in time with visual timeline of all alarms for the day.
- Loud notification sound with one-tap mute/dismiss.

### 3.4 Settings & Customization (`SettingsScreen`)
- Theme selection (Light, Dark, System).
- Accent color palette selector.
- Global sound and vibration toggles with sound previews.
- Default alarm sound selection.
- Screen Keep-Awake toggle.
- Clear History & Reset Demo Data utilities.

---

## 4. Preset Templates Library

### Fitness & Sports Presets
1. **Tabata HIIT (4 Min)**: 8 sets of 20s Work + 10s Rest (Loop enabled).
2. **EMOM 10-Min (Every Minute on the Minute)**: 10 sets of 45s Work + 15s Rest.
3. **Boxing / Sparring 3-Min Rounds**: 3 rounds of 3m Work + 1m Rest.
4. **Run / Walk Cardio Intervals**: 5 rounds of 2m Run + 1m Walk.
5. **7-Minute Full Body Circuit**: 12 movements (30s Work + 10s Rest each).

### Work & Productivity Presets
1. **Hourly Boss Report / Check-in**: 8:00 AM – 5:00 PM, alarm every 1 hour.
2. **Bi-Hourly Supervisor Update**: 9:00 AM – 5:00 PM, alarm every 2 hours.
3. **Pomodoro 25/5 Deep Work**: 4 cycles of 25m Focus + 5m Break + 15m Long Break.
4. **50/10 Ultradian Rhythm**: 50m Focus + 10m Rest.
5. **Stand & Hydrate Hourly**: 55m Focus + 5m Walk/Hydrate.
6. **20-20-20 Eye Strain Break**: 20m Focus + 20s Distance Rest.

---

## 5. Technical Implementation & Platform Readiness

### 5.1 Drift Compensation & Backgrounding
- Active timers store an absolute target `DateTime deadline`.
- On every 100ms tick and lifecycle resumption (`didChangeAppLifecycleState`), `remainingMs = deadline.difference(now)` is computed.
- If multiple timers elapsed while the phone was backgrounded or screen locked, the sequence fast-forwards cleanly to the exact active timer with overshoot compensation.

### 5.2 Wakelock Management
- Active countdowns trigger `WakelockPlus.enable()`.
- Pausing, completing, or exiting triggers `WakelockPlus.disable()`.

### 5.3 Orientation Configuration
- `SystemChrome.setPreferredOrientations` will support:
  - `DeviceOrientation.portraitUp`
  - `DeviceOrientation.portraitDown`
  - `DeviceOrientation.landscapeLeft`
  - `DeviceOrientation.landscapeRight`

### 5.4 Test Strategy
- Unit tests for Hive schema conversions, phase transitions, and wall-clock time math.
- Unit tests for interval calculation crossing midnight and periodic alarms.
- Widget tests for `ActivityListScreen`, `TimerScreen` (portrait and landscape layouts), `IntervalTimerScreen`, and `SettingsScreen`.
- Zero compiler warnings / lints under `flutter_lints: ^6.0.0`.
