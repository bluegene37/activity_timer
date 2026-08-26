# Changelog

All notable changes to **Activity Timer** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
