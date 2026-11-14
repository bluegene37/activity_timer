# Changelog

All notable changes to **Activity Timer** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-11-06

### Added
- **Alert by Time Mode & Day-of-Week Recurrence**:
  - Point-in-time single-clock alerts (`Alert at Time`) alongside periodic interval windows, with quick time preset chips (`+15m`, `+30m`, `+1h`, `9:00 AM`, `12:00 PM`, `6:00 PM`).
  - Weekday recurrence selector (`Every Day`, `Weekdays`, `Weekends`, `One-time`, or custom `M–S` days) and a 1-tap armed schedule switch on each interval card.
- **Quick Countdown Timer**:
  - Instant 1-tap countdown chips (`1m`, `3m`, `5m`, `10m`, `15m`, `30m`) and a custom `H:M:S` wheel picker at the top of the Activity Routines tab.
- **Snooze / Extend Controls & Notification Actions**:
  - In-session `+1m` and `+5m` adjustment pills, completion `Snooze +1m` / `Snooze +5m` buttons, and OS notification `Snooze 5m` and `Dismiss` action buttons.
- **3-2-1 Countdown Beeps & 50% Halfway Warning Cue**:
  - Configurable final 3-second countdown ticks and 50% halfway warning audio cue in Settings.

### Changed
- **Android Build Toolchain (Flutter 3.50.0 Compatibility)**:
  - Upgraded Gradle wrapper to `9.5.0`, Android Gradle Plugin to `9.3.1`, Kotlin Gradle Plugin to `2.4.20`, and JVM compilation target to Java 17.

### Fixed
- **QA Responsiveness, Accessibility, Validation & Interval Session Sync**:
  - Resolved narrow-screen and large accessibility text-scale layout overflows across navigation tabs, floating session pills, run screens, edit screens, and duration dialogs.
  - Synchronized `IntervalTimer.isActive` state with active and restored background interval sessions and tightened timer/brew form validation and semantics labels.
- **Notification Sound & Multi-Floater Restoration**:
  - Added Android R8/ProGuard `keep.xml` rules for raw alarm sounds, upgraded notification channel importance/audio attributes, and suppressed duplicate in-app completion cues when resuming from a fired background notification.
  - Persisted and restored running Interval and Coffee Brew sessions across cold launches alongside Activity routines.
- **Background Session & Floating Run Restoration**:
  - Persisted active routine state to local Hive storage on all lifecycle transitions (start, pause, resume, preparation completion, and step advancement).
  - Automatically restored running activity routines upon cold boot or notification tap, computing precise elapsed wall-clock time and handling step overshoots.
  - Ensured floating run overlay pill (`_ActivityFloater`) renders immediately on launch with the accurate active step and remaining countdown timer.
  - Handled notification click events to direct user directly to the running routine timer screen.
  - Safely cleared active session records and canceled pending alarms upon routine completion or dismissal.

## [1.0.3] - 2026-11-03

### Added
- **Theme & UI Polish**:
  - Dynamically adapt Coffee Brew screens to modern theme styling and iOS accent colors.
  - Enhanced Brew List screen header typography and iconography.
  - Searchable preset bottom sheet and segmented duration controls.

### Changed
- **Dependencies & SDKs**:
  - Upgraded Flutter SDK constraints and external package dependencies.
  - Enhanced TestFlight and Google Play deployment workflows.

### Fixed
- **Notifications & Background Alarms**:
  - Segmented notification ID allocations per session type to eliminate sound cue conflicts.
  - Pre-scheduled full routine alarm timers during preparation countdowns.
- **Layout & Accessibility**:
  - Resolved text clipping in settings list tiles across large accessibility dynamic type sizes.
  - Added safe area padding and scroll insets to edit screens.

## [1.0.0] - 2026-08-26

### Added
- **Activity Routines**:
  - Multi-step timer sequences with customizable duration, step names, colors, and icons.
  - Drag-and-drop step reordering with real-time sequence updates.
  - Optional sequence looping for continuous circuit training and routines.
- **Preset Library**:
  - Built-in templates for Pomodoro (25m / 5m), Tabata (20s / 10s x 8), Box Breathing (4s / 4s / 4s / 4s), and the 7-Minute Workout.
  - One-tap duplicate and customization into user routine library.
- **Interval Timers**:
  - Flexible interval scheduler across designated time windows (e.g., hourly reminder from 8:00 AM to 5:00 PM).
  - Floating persistent progress overlay while background intervals are running.
- **Pour-Over Coffee Brew Timer**:
  - Dedicated pour-over recipe execution with staged blooms, continuous pours, and drawdowns.
  - Dynamic dose-to-water target weight calculation (grams) based on custom brew ratios.
  - Interactive recipe builder with step invariant validation.
- **Wall-Clock Countdown Engine**:
  - Epoch timestamp-based delta calculations ensuring millisecond precision even when the OS background-throttles the app.
  - Automatic missed-step catch-up upon returning from background.
  - Screen wake-lock toggle during active timer sessions.
- **Audio & Haptic Feedback**:
  - Sound alert engine with multiple bundled high-fidelity sound cues (`alert`, `beep`, `bell`, `chime`, `digital`, `gentle`, `marimba`, `siren`, `timer_complete`).
  - Per-timer sound overrides and global default sound picker.
  - Tactile haptic feedback on state changes, selections, and timer expirations.
- **Theming & Design System**:
  - Material 3 theme engine supporting System, Light, and Dark modes.
  - Dynamic iOS accent color customization.
  - Bespoke Japanese Washi-paper aesthetic for the Coffee Brew experience with warm earth tones and custom typography (`Literata`).
- **Session History & Local Stats**:
  - Offline logging of completed routines, intervals, and brews.
  - Summary stats sheet tracking total focus time and session counts.
- **100% Offline Architecture & Privacy**:
  - Zero network permissions, no telemetry, and no third-party trackers.
  - Local database powered by Hive CE.
  - Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) declaring zero data collection.
