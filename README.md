# Activity Timer

A simple, fully offline, versatile activity timer for iOS and Android, built with Flutter.

## Features

- **Activity routines** — build sequences of named timers (e.g. Warm Up → Work → Rest), reorder them by drag and drop, and run them back to back with optional looping.
- **Preset library** — one-tap templates for Pomodoro, Tabata, Box Breathing, and the 7-Minute Workout.
- **Interval timers** — schedule recurring alarms across a time window (e.g. every hour from 8 AM to 5 PM).
- **Accurate countdowns** — timers are wall-clock based, so they stay correct even when the app is backgrounded; missed steps are caught up automatically on return.
- **Session history** — completed sessions are logged locally with totals shown in the stats sheet.
- **Per-timer alarm sounds** — five built-in sounds, selectable per timer or as an app-wide default, with optional vibration.
- **Theming** — System/Light/Dark mode and a selectable accent color.
- **100% offline** — all data is stored on-device with Hive; no network access, accounts, or tracking.

## Architecture

| Layer | Location | Notes |
|---|---|---|
| Models | `lib/models/` | Hive-annotated data classes (`TimerSequence`, `ActivityTimer`, `IntervalTimer`, `SessionHistory`, settings) |
| Persistence | `lib/services/database_service.dart` | Hive boxes + preset/demo data |
| State | `lib/controllers/` | GetX controllers per screen |
| UI | `lib/screens/`, `lib/components/` | Screens and reusable widgets |
| Theme | `lib/theme/app_theme.dart` | Material 3 light/dark themes seeded from the accent color |
| Routing | `lib/routes/` | GetX pages |

## Development

```bash
flutter pub get
flutter run
```

Regenerate Hive adapters after changing models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run checks:

```bash
flutter analyze
flutter test
```
