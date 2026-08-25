# Architecture & Contributor Guide

How this app is put together, why it is put together that way, and the exact
steps to add a feature without guessing.

- [The app in one paragraph](#the-app-in-one-paragraph)
- [Layers](#layers)
- [Folder map](#folder-map)
- [The three timer subsystems](#the-three-timer-subsystems)
- [How alarms actually work](#how-alarms-actually-work)
- [Data & persistence rules](#data--persistence-rules)
- [Adding a feature: the playbook](#adding-a-feature-the-playbook)
- [Testing rules that will save you hours](#testing-rules-that-will-save-you-hours)
- [Tooling & dependency review](#tooling--dependency-review)
- [Known sharp edges](#known-sharp-edges)

---

## The app in one paragraph

An **offline-first** Flutter timer app with three timer kinds — activity
routines, interval schedules, and coffee pour-over brews. No backend, no
account, no network calls. State lives in Hive on the device; a session keeps
running when its screen is closed, and boundaries ring through both in-app
audio and OS notifications.

---

## Layers

Data flows down, events flow up. Nothing below reaches back into a layer above.

```
screens/          Widgets. Layout and interaction only.
   |  reads Rx values, calls methods
controllers/      Session engines and list state. No BuildContext, no widgets.
   |  calls
services/         Singletons: persistence, audio, OS scheduling.
   |  reads/writes
models/           Hive-annotated data + pure computation (no I/O).
```

**The rule that keeps this honest:** a controller must be testable with no
widget tree, and a model must be testable with no Hive box. If you need
`BuildContext` in a controller, the logic belongs in the screen; if you need
disk in a model, it belongs in a service.

| Layer | May import | May **not** import |
| --- | --- | --- |
| `models/` | other models | services, controllers, screens, Flutter widgets |
| `services/` | models | controllers, screens |
| `controllers/` | models, services | screens, `BuildContext` |
| `screens/`, `components/` | everything | — |

---

## Folder map

```
lib/
  main.dart               Boot: Hive init → DB init → settings → GetX → runApp
  models/                 Hive types + pure logic. *.g.dart is GENERATED.
  services/               Singletons. One responsibility each.
    database_service.dart   All Hive box access. Nothing else opens a box.
    cue_player.dart         In-app audio + haptics for every timer.
    alarm_scheduler.dart    OS notifications for backgrounded sessions.
    brew_session_service.dart      Owns the one running brew.
    interval_session_service.dart  Owns the one running interval schedule.
  controllers/            GetX controllers: list state and run engines.
  screens/                One file per full-page screen.
  components/             Reusable widgets shared by 2+ screens.
  navigation/             MainNavigation: the tab shell and floating chips.
  routes/                 app_routes.dart (names) + app_pages.dart (bindings).
  theme/                  app_theme.dart (iOS look) + brew_theme.dart (Coffee).
  utils/                  Pure helpers.
test/                     One file per unit under test. Mirrors lib/.
assets/sounds/            Alarm cues. Declared wholesale in pubspec.
assets/icon/              Icon sources; launcher icons are GENERATED from these.
docs/superpowers/         Specs and plans for features already built.
```

---

## The three timer subsystems

They deliberately share the layer shape but not the code, because their clocks
differ in kind:

| | Activity routine | Interval schedule | Brew |
| --- | --- | --- | --- |
| Clock | countdown per step | wall-clock alarm times | countdown per step |
| Engine lives in | `screens/timer_screen.dart` | `controllers/interval_run_controller.dart` | `controllers/brew_run_controller.dart` |
| Survives screen close | ❌ not yet | ✅ via `IntervalSessionService` | ✅ via `BrewSessionService` |
| Minimizes to a chip | ❌ not yet | ✅ | ✅ |

**The session-service pattern** (use it for any new long-running timer):

```dart
// A singleton owns the controller, so popping the screen minimizes
// instead of killing the session.
final controller = XSessionService().obtain(model);   // same id resumes
XSessionService().releaseIfIdle();                    // called from dispose
```

The screen *borrows* the controller and takes a `controller` parameter as a
test seam. `MainNavigation` watches the service's `active` value and renders a
floating chip whenever a session is live.

> **Known debt:** `timer_screen.dart` still owns its engine inline (~1,100
> lines), which is why activity routines cannot minimize. Extracting an
> `ActivityRunController` + `ActivitySessionService` is the next refactor, and
> the interval extraction is the worked example to copy.

---

## How alarms actually work

Two independent mechanisms, deliberately overlapping:

1. **In-app cue** — `CuePlayer` plays audio + haptics the instant a boundary
   is crossed. Works only while Flutter is running.
2. **OS notification** — `AlarmScheduler` hands every *future* boundary to the
   system up front. Works when the app is backgrounded or the phone is locked.

Whichever fires first, the user is told. A denied notification permission
costs only the background half, never the foreground cue.

**Every state transition must re-sync the OS list.** Start, pause, resume,
skip, reset, finish, dispose. Miss one and users get a phantom alarm from a
session they stopped — the failure mode to watch for in review.

Two audio-session decisions worth knowing before you change them:

- `respectSilence: false` → iOS `playback` category → **alarms still sound
  with the ringer switch off.** That is the point of an alarm.
- `duckOthers` → music and podcasts dip for the cue instead of being stopped.

Notification sounds use the **system default**, not our custom WAVs: iOS
requires notification audio to be bundled as an Xcode resource, not a Flutter
asset. Adding custom sounds means editing `project.pbxproj` (iOS) and
`res/raw/` (Android). Decide it is worth that before starting.

---

## Data & persistence rules

**All Hive access goes through `DatabaseService`.** No screen or controller
opens a box.

**Hive type ids are permanent.** Adding a field is safe; renumbering,
reordering, or reusing an id corrupts existing installs. Current allocation:

| id | Type | | id | Type |
| --- | --- | --- | --- | --- |
| 0–4 | activity/interval/session models | | 8 | `BrewRecipe` |
| 5 | `AlarmSound` | | 9 | `BrewStep` |
| 6–7 | settings/theme | | 10–11 | `BrewStepKind`, `BrewMethod` |

**Next free id: 12.**

Adding an enum value is backwards-compatible — append with the next
`@HiveField` index, never insert. After any model edit:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Never hand-edit `*.g.dart`; it is excluded from analysis and regenerated.

---

## Adding a feature: the playbook

Worked example: *"add a Tabata preset timer."*

### 1. Model first — `lib/models/`

Create `tabata_preset.dart`. Pure data + computation, `@HiveType(typeId: 12)`
(take the next free id and update the table above). Then regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Write `test/tabata_preset_test.dart` alongside it — pure model tests need no
Hive and no widgets, so they stay fast.

### 2. Persistence — `lib/services/database_service.dart`

Add a box getter and the CRUD methods. Register the adapter (the generated
`hive_registrar.g.dart` handles this once the model is annotated).

### 3. Engine — `lib/controllers/`

If it runs on a clock, create `tabata_run_controller.dart` and **inject every
edge**:

```dart
TabataRunController({
  required this.preset,
  CuePlayer? cuePlayer,          // audio
  AlarmScheduler? scheduler,     // OS notifications
  DateTime Function()? clock,    // makes time testable
});
```

That constructor shape is the single most important convention in this
codebase: it is what makes the engines testable without a device.

### 4. Session ownership — `lib/services/`

Want it to survive the screen closing? Copy
`interval_session_service.dart` verbatim and swap the types.

### 5. Screen — `lib/screens/`

`tabata_screen.dart`, borrowing the controller from the session service and
accepting a `controller` parameter as a test seam. Minimize = chevron-down in
the leading slot; ending the session = X in the actions, behind a confirm.

### 6. Route — `lib/routes/`

Add the name to `app_routes.dart`, the `GetPage` to `app_pages.dart`.

> ⚠️ **Push with `Get.toNamed<dynamic>` and narrow the result.** A concrete
> type parameter crashes at runtime — see [Known sharp edges](#known-sharp-edges).

### 7. Navigation — `lib/navigation/main_navigation.dart`

Add a tab and, if the session can minimize, a floater in the `Column` of
chips.

### 8. Tests — `test/`

At minimum: model test, controller test (fake clock + fake cue player + fake
scheduler), screen widget test. Add the floater test if it minimizes.

### 9. Verify — both must pass, no exceptions

```bash
flutter analyze && flutter test
```

---

## Testing rules that will save you hours

These are all learned the hard way in this repo.

**Hive writes hang — they do not fail — inside the fake-async zone.** Any
`box.put` reached from a `testWidgets` body must run inside `tester.runAsync`,
including the tap that triggers a save:

```dart
await tester.runAsync(() async {
  await tester.tap(find.byTooltip('Enable loop'));
  await Future<void>.delayed(const Duration(milliseconds: 50));
});
```

**`pumpAndSettle` never settles on `MainNavigation`** — those screens animate
continuously. Use bounded pumps:

```dart
for (var i = 0; i < 5; i++) {
  await tester.pump(const Duration(milliseconds: 100));
}
```

**`wakelock_plus` mocks the pigeon channel**, not a plain `MethodChannel`:

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
```

**The pending-timer check runs before `addTearDown`.** A controller with a
ticker that no widget hosts needs a synchronous `controller.onClose()` at the
end of the test body.

**An `async` helper that returns a `Future` awaits it.** Returning a dialog's
future from an `async` function hangs the test until the dialog closes; assign
it to a variable the test reads instead.

**Assert on bytes, not filenames.** `test/alarm_assets_test.dart` exists
because a cue once shipped as a 154-byte text file named `.mp3`: the code ran,
the exception was swallowed, and the alarm was silent.

---

## Tooling & dependency review

Reviewed 2026-08-26. Every direct dependency is on its latest version.

### Keep

| Package | Why it is the right fit |
| --- | --- |
| **hive_ce** + **hive_ce_flutter** | **Yes — this is the maintained Community Edition.** The original `hive` was abandoned at 2.2.3; `hive_ce` is the active fork and where new work lands. Right shape for document-style local data with no server. |
| **audioplayers** | Low-overhead short-cue playback with the audio-session control alarms need. `just_audio` is stronger for streaming/playlists — not this workload. |
| **wakelock_plus** | The maintained successor to `wakelock`. No real alternative. |
| **flutter_local_notifications** | The standard for scheduled local notifications; `zonedSchedule` + exact alarm modes are exactly the primitive a timer needs. |
| **timezone** | Required by the above for DST-correct scheduling. |
| **intl**, **uuid**, **path_provider** | Boring, stable, correct. |
| **flutter_launcher_icons**, **flutter_native_splash** | Build-time generators; zero runtime cost. |

### Keep, with eyes open

**`get` (GetX)** — used for state, DI, routing, and dialogs. The honest
picture: one-package-does-everything, a thin maintenance bus factor, a v5 that
has been "coming" for years, and an API sharp enough that it has already cost
this project a production crash (typed named routes). The 2026 default for a
new app would be **Riverpod + go_router**.

**Recommendation: do not migrate now.** GetX is load-bearing across ~20 files
and 149 tests; a rewrite would burn days and re-open settled behavior for no
user-visible gain. Instead, *contain* it:

- New engines stay plain classes with injected edges — only their observable
  fields use `Rx`. Both session services already follow this.
- No `Get.context` inside controllers where a screen can pass what it needs.
- Route pushes use `Get.toNamed<dynamic>` (below).

Revisit if GetX goes a full year without a release, or if a second crash
traces to its API. The containment above keeps that migration to controllers
and routes rather than the whole app.

### Gaps worth deciding on

| Gap | Recommendation |
| --- | --- |
| **No crash reporting** | Real gap for production. `sentry_flutter` is the usual pick and works offline-first (events queue until connectivity). Needs an account + DSN, so it is your call to make. |
| **Android toolchain warning** | The build warns that Kotlin 2.2.20 support "will soon be dropped" (needs ≥ 2.3.20); AGP is 8.11.1. Low urgency, but do it before it becomes forced. |
| **No release signing** | `android/app/build.gradle.kts` still signs release with the **debug** key. Must be fixed before any store upload — keystore + `key.properties`, both already gitignored. |
| **Test coverage not enforced** | CI uploads `lcov.info` but sets no floor. Add a threshold once coverage is measured. |

---

## Known sharp edges

**GetX named routes are always `GetPageRoute<dynamic>`.** A concrete type
parameter throws at runtime:

```dart
// CRASHES: type 'GetPageRoute<dynamic>' is not a subtype of 'Route<bool?>?'
final ok = await Get.toNamed<bool>(Routes.editTimer);

// CORRECT: push dynamic, narrow the result
final result = await Get.toNamed<dynamic>(Routes.editTimer);
if (result == true) { /* ... */ }
```

`Get.dialog<T>` and `Get.back<T>` keep concrete types — they do not go through
the route generator.

**Theme text styles must agree on `inherit`.** `MaterialApp` lerps `ThemeData`
over ~200 ms on a theme switch, and `TextStyle.lerp` throws when two styles
disagree. Both themes derive their button styles from the same base for this
reason; `test/coffee_theme_test.dart` pumps mid-animation frames to prove it.

**`Get.snackbar` inside `runAsync` schedules a real-clock timer.** Flush it
with `pump(4s)` or `Get.closeAllSnackbars()` in the same zone.

**The iOS Simulator MCP is broken on this machine.** Use:

```bash
flutter build ios --simulator --debug
```

then `xcrun simctl boot/install/launch` with bundle id
`dev.genexis.activitytimer`. Prefer widget tests over the simulator for
interactive flows.
