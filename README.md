# ⏱️ Activity Timer

<div align="center">

**A private, offline-first multi-activity routine, interval, and pour-over coffee timer for Android & iOS.**

[![CI](https://github.com/genexis-dev/activity_timer/actions/workflows/ci.yml/badge.svg)](https://github.com/genexis-dev/activity_timer/actions/workflows/ci.yml)
[![Release](https://github.com/genexis-dev/activity_timer/actions/workflows/release.yml/badge.svg)](https://github.com/genexis-dev/activity_timer/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/genexis-dev/activity_timer?color=blue)](https://github.com/genexis-dev/activity_timer/releases)
[![Flutter SDK](https://img.shields.io/badge/Flutter-%5E3.7.0-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-brightgreen)](#-installation--download-matrix)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline-success)](#-privacy--security)

</div>

---

## ✨ Features & Highlights

- 🔄 **Multi-Step Activity Routines**: Create custom multi-phase workout or workflow sequences (e.g. *Warm Up* → *High Intensity* → *Rest*). Easily reorder steps with drag-and-drop and enable optional sequence looping.
- ⚡ **Preset Library**: Ready-to-go, scientifically proven templates including **Pomodoro (25m/5m)**, **Tabata (20s/10s x8)**, **Box Breathing (4-4-4-4)**, and the **7-Minute Workout**.
- 🔔 **Interval Alarms**: Schedule recurring time-window alarms (e.g., chime every 45 minutes between 8:00 AM and 5:00 PM) with a floating progress monitor.
- ☕ **Pour-Over Coffee Brew Timer**: Handcrafted pour-over companion that calculates target water weight in grams from your coffee dose and guides you step-by-step through bloom, pours, and drawdowns.
- ⏱️ **Wall-Clock Precision**: Timer logic calculates real-time epoch deltas, ensuring millisecond accuracy even when backgrounded or throttled by mobile operating systems.
- 🔊 **Rich Audio Cues & Haptics**: Bundled sound cues (`alert`, `beep`, `bell`, `chime`, `digital`, `gentle`, `marimba`, `siren`, `timer_complete`) with per-step overrides and customizable haptic feedback.
- 🎨 **Adaptive Theming & Japanese Washi Style**: Material 3 theming (Light / Dark / System) with selectable accent colors for routines, plus a specialized Washi paper aesthetic for the coffee flow.
- 🔒 **100% Private & Offline**: Built on local [Hive CE](https://github.com/isar/hive_ce) storage. Zero telemetry, zero external network requests, zero user tracking.

---

## 🏛️ Architecture & Project Structure

The project follows a reactive, separation-of-concerns architecture powered by `signals` and `get_it`:

```text
lib/
├── components/     # Reusable UI widgets (ring timers, sound pickers, color chips)
├── controllers/    # Signal-based ViewModels managing screen state and timers
├── models/         # Hive-persisted data classes and type adapters
├── routes/         # go_router declarative routing table
├── screens/        # Screen widgets (Routines, Intervals, Coffee, Settings)
├── services/       # Core singletons (Hive DatabaseService, AlarmScheduler, Service Locator)
├── theme/          # AppTheme tokens, Material 3 palettes, and BrewTheme styles
└── utils/          # Formatting helpers, time math, and sound player utilities
```

| Layer | Responsibility | Key Technologies |
|---|---|---|
| **Models** | Type-safe data entities and serialization | `hive_ce`, `hive_ce_generator` |
| **State** | Reactive, granular view-model state management | `signals`, `signals_flutter` |
| **Dependency Injection** | Lazy singleton and factory resolution | `get_it` |
| **Navigation** | Deep-link capable declarative routing | `go_router` |
| **Background & Alarms** | Exact OS notifications and wake-lock | `flutter_local_notifications`, `wakelock_plus` |
| **Audio** | Low-latency cue playback | `audioplayers` |

---

## 📦 Installation & Download Matrix

| Platform | Channel / Asset | Distribution Format | Status |
|---|---|---|---|
| **Android** | [GitHub Releases](https://github.com/genexis-dev/activity_timer/releases) | `.apk` (Universal) / `.aab` (Bundle) | Available |
| **Android** | Google Play Store | Play Store Track | Ready for upload |
| **iOS** | [GitHub Releases](https://github.com/genexis-dev/activity_timer/releases) | `.xcarchive.zip` (Symbols included) | Available |
| **iOS** | Apple App Store | TestFlight / App Store | Ready for upload |

---

## 🛠️ Local Development & Setup

### Prerequisites
- **Flutter SDK**: `^3.7.0` ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: `^3.7.0` (included with Flutter)
- **Java**: JDK 17 (for Android builds)
- **Xcode**: 15+ (for iOS builds, macOS only)

### Setup Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/genexis-dev/activity_timer.git
   cd activity_timer
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Hive type adapters and codegen**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Verify static analysis and run tests**:
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```

5. **Launch the application**:
   ```bash
   # Run on connected device or active emulator/simulator
   flutter run
   ```

---

## 🚀 Release & Packaging Guide

The version is managed in `pubspec.yaml` (`version: X.Y.Z+N`) as the single source of truth.

### Android Release Build

To build an optimized Android App Bundle (`.aab`) with obfuscation and symbol generation:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

To build a standalone Release APK (`.apk`):

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

### iOS Release Build

To build an unsigned Xcode archive for distribution:

```bash
flutter build ipa --release --no-codesign \
  --obfuscate \
  --split-debug-info=build/symbols/ios
```

For signed App Store / TestFlight submission via local Xcode:

```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols/ios
```

> [!IMPORTANT]
> Always archive the generated symbols directory (`build/symbols/`) alongside release binaries to preserve crash de-obfuscation capabilities.

For full signing instructions, keystore generation, and pre-flight checklists, see [RELEASING.md](RELEASING.md).

---

## 🛡️ Privacy & Security

Activity Timer is designed with an uncompromising commitment to privacy:
- **No Internet Connectivity**: The app does not request network access permissions.
- **No Analytics / Trackers**: Zero telemetry, SDK metrics, or third-party trackers.
- **On-Device Storage Only**: All routines, intervals, custom recipes, and session history remain securely stored in local encrypted Hive boxes on your device.
- **Apple Privacy Manifest**: Compliant with Apple's `PrivacyInfo.xcprivacy` declaring 0 tracked data categories.

For vulnerability disclosure or security notices, please see [SECURITY.md](SECURITY.md).

---

## 🤝 Contributing

Contributions, bug reports, and feature proposals are welcome! Please check out [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code style, test expectations, and pull request process.

---

## 📄 License & Credits

- **License**: Released under the [MIT License](LICENSE). Copyright © 2026 [genexis.dev](https://genexis.dev).
- **Typography**: [Literata](https://fonts.google.com/specimen/Literata) used under the SIL Open Font License (`assets/fonts/OFL.txt`).
- **Icons**: Designed with Material Icons and Cupertino Icons.
