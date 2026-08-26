# Architecture & Contributor Guide

How this app is put together, why it is put together that way, and the exact
steps to add a feature without guessing.

- [The app in one paragraph](#the-app-in-one-paragraph)
- [The pattern, named](#the-pattern-named)
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

## The pattern, named

**MVVM with a service layer.** Not Clean Architecture, and deliberately so —
the reasoning is below, along with the trigger for changing our minds.

| MVVM role | Lives in | Holds | Example |
| --- | --- | --- | --- |
| **Model** | `models/` | data + pure computation, no I/O | `BrewRecipe.targetGramsAt(i)` |
| **View** | `screens/`, `components/` | layout and gestures only | `BrewRunScreen` |
| **ViewModel** | `controllers/` | observable state + the logic that drives it | `BrewRunController` |
| *(supporting)* | `services/` | I/O and cross-screen ownership | `DatabaseService`, `CuePlayer` |

The View never reaches past the ViewModel for state, and the ViewModel never
imports a widget:

```
View            SignalBuilder reads controller.remainingMs.value
  |  calls methods                              ^
  v                                             | signal changes
ViewModel       controller.pause()  ────────────┘
  |  calls
  v
Service         DatabaseService, CuePlayer, AlarmScheduler
  |  reads/writes
  v
Model           TimerSequence, BrewRecipe
```

### Three deliberate deviations from textbook MVVM

**1. Services own ViewModel lifetime.** In plain MVVM a View creates its
ViewModel and both die together. Here a running timer must outlive its
screen, so `XSessionService` owns the controller and the screen *borrows*
it. That is the whole reason minimize-to-a-chip works.

**2. Side-effecting services are interface-inverted; the database is not.**
`CuePlayer` and `AlarmScheduler` are `abstract interface class` because
tests must substitute them — audio and OS notifications cannot run in a
widget test. `DatabaseService` is a concrete singleton, because Hive already
runs fine in tests against a temp directory, so an interface would buy
indirection and nothing else.

**3. ViewModels take their edges as constructor parameters.** Manual
dependency injection, no framework:

```dart
BrewRunController({
  required this.recipe,
  CuePlayer? cuePlayer,          // audio
  AlarmScheduler? scheduler,     // OS notifications
  DateTime Function()? clock,    // time itself
});
```

Each defaults to the real thing and is overridden in tests. This is the
single most important convention in the codebase: it is what lets the
engines be tested with a fake clock and no device.

### Why not Clean Architecture

Clean Architecture would add use-cases/interactors, domain entities kept
free of persistence, and repository interfaces the domain depends on rather
than concrete data sources. This app has none of that, on purpose:

| Clean would require | Reality here |
| --- | --- |
| Domain entities free of persistence | `@HiveType` annotations sit directly on `BrewRecipe` and friends |
| Repository interfaces + implementations | one concrete `DatabaseService` |
| Use-cases between ViewModel and repository | controllers call the service directly |

Those indirections pay off when there are several data sources to swap, a
domain shared across platforms, or teams working behind a stable interface.
This app is offline-only, single data source, no backend, no network. Adding
the layers would mean more files, more mapping code, and more places to look
when something breaks — for no behavior anyone can observe.

> **Revisit when any of these becomes true:** a second data source appears
> (sync, an API, an export target); the same domain logic needs to run
> somewhere without Flutter; or a model needs a shape the storage format
> cannot express. The first of those is the likely one, and the migration is
> contained: introduce a repository interface, let `DatabaseService`
> implement it, and point the controllers at the interface. Nothing above
> the ViewModel changes.

### Which layer does my new thing go in?

| If it… | It belongs in | And it must not |
| --- | --- | --- |
| holds data or computes from it | `models/` | touch disk, audio, or widgets |
| talks to disk, the OS, or hardware | `services/` | know about controllers or screens |
| owns state a screen renders | `controllers/` | import `BuildContext` or widgets |
| lays out pixels or handles gestures | `screens/` | contain business rules |
| is reused by 2+ screens | `components/` | own app state |

---

## Layers

The same structure as above, stated as import rules. Data flows down, events
flow up, and nothing below reaches back into a layer above.

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
  main.dart               Boot: Hive → DB → settings → locator → runApp
  models/                 Hive types + pure logic. *.g.dart is GENERATED.
  services/               Singletons. One responsibility each.
    database_service.dart   All Hive box access. Nothing else opens a box.
    cue_player.dart         In-app audio + haptics for every timer.
    locator.dart            get_it registrations for the controllers.
    ui_messenger.dart       Messages and dialogs without a BuildContext.
    alarm_scheduler.dart    OS notifications for backgrounded sessions.
    brew_session_service.dart      Owns the one running brew.
    interval_session_service.dart  Owns the one running interval schedule.
  controllers/            Plain classes: list state and run engines.
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
| Engine lives in | `controllers/activity_run_controller.dart` | `controllers/interval_run_controller.dart` | `controllers/brew_run_controller.dart` |
| Survives screen close | ✅ via `ActivitySessionService` | ✅ via `IntervalSessionService` | ✅ via `BrewSessionService` |
| Minimizes to a chip | ✅ | ✅ | ✅ |

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

All three now follow the same shape. `timer_screen.dart` used to own its
engine inline (1,159 lines, 12 business-state fields on the `State`, and a
`setState` that rebuilt the whole tree every 100 ms); it is now 819
presentational lines driving `ActivityRunController`.

> **Obx subscribes only to what its own closure reads.** Compute observable
> values *inside* the `Obx(() { ... })` builder, never above it — a read in
> the enclosing `build` leaves the widget subscribed to nothing, and the
> clock silently freezes. This bit during the extraction and is exactly the
> kind of bug a widget test catches and a glance does not.

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

**Background alarms use the routine's own cue, not the system default.**
Each platform reaches its copy differently, and neither can read a Flutter
asset directly:

| Platform | Where the sound must live | How it is put there |
| --- | --- | --- |
| Android | `android/app/src/main/res/raw/` | committed build-time copies, referenced by `RawResourceAndroidNotificationSound` |
| iOS | the app bundle, or `Library/Sounds` in the app container | copied out of `assets/` on first scheduler init, so `assets/` stays the single source of truth and no `project.pbxproj` surgery is needed |

**Android ties a sound to its notification channel and will not let it
change afterwards**, so each cue gets its own channel
(`activity_timer_alarms_<sound>`). Adding a sound therefore means: add the
enum value, drop the file in `assets/sounds/`, *and* copy it into
`res/raw/` with a lowercase name. `test/alarm_scheduler_test.dart` fails if
you forget the last step.

### Can we use the device's own alarm sounds?

Asked often, so the answer is written down:

| | Pick from the device's sounds | Create an alarm in the system Clock app |
| --- | --- | --- |
| **Android** | **Yes** — `RingtoneManager.ACTION_RINGTONE_PICKER` returns a content URI, usable via `UriAndroidNotificationSound`. Needs a small platform channel; no maintained plugin covers it well. | **Yes** — `AlarmClock.ACTION_SET_ALARM`, but it is a one-way hand-off: the alarm lives in the Clock app, outside our control, so it cannot drive interval or step boundaries. |
| **iOS** | **No.** Apple exposes no API to enumerate or pick system ringtones and alarm sounds. Notification audio must ship inside the app. | **No.** Third-party apps cannot add entries to the Clock app. |

So a cross-platform "choose from your device" picker is not possible; it
would be an Android-only affordance. That is why the app bundles its own
cues — the one approach that behaves identically on both platforms — and
why the loud ones (Alert, Siren) were synthesized rather than borrowed.

Two iOS notes worth knowing before someone proposes them:

- **Critical alerts** (bypassing Silent and Focus, at a fixed volume) need
  the `com.apple.developer.usernotifications.critical-alerts` entitlement,
  which Apple grants case by case and effectively reserves for medical,
  health and safety apps. Not available to a timer.
- **Keeping the app alive in the background** by holding an audio session
  open is a real technique, but App Review guideline 2.5.4 expects the
  `audio` background mode to mean actual continuous playback. Scheduled
  notifications are the sanctioned route.

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

The order is not arbitrary — it walks the layers bottom-up, so every step
only depends on things that already exist and can be tested the moment it is
written. Each heading names the MVVM role it produces.

| Step | Produces | Testable with |
| --- | --- | --- |
| 1 | Model | plain unit test, no Hive, no widgets |
| 2 | data access | temp-directory Hive |
| 3 | ViewModel | fake clock + fake services, no device |
| 4 | lifetime owner | plain unit test |
| 5–7 | View + wiring | widget tests |
| 8–9 | the gate | `flutter analyze && flutter test` |

### 1. Model first — `lib/models/`

Create `tabata_preset.dart`. Pure data + computation, `@HiveType(typeId: 12)`
(take the next free id and update the table above). Then regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Write `test/tabata_preset_test.dart` alongside it — pure model tests need no
Hive and no widgets, so they stay fast.

### 2. Data access — `lib/services/database_service.dart`

Add a box getter and the CRUD methods. Register the adapter (the generated
`hive_registrar.g.dart` handles this once the model is annotated).

### 3. ViewModel — `lib/controllers/`

The ViewModel: observable state plus the logic that drives it, and no
`BuildContext` anywhere in it. If it runs on a clock, create
`tabata_run_controller.dart` and **inject every edge**:

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

### 4. Lifetime owner — `lib/services/`

Want it to survive the screen closing — the deviation from textbook MVVM
described above? Copy `interval_session_service.dart` verbatim and swap the
types. Skip this step for a feature whose state dies with its screen.

### 5. View — `lib/screens/`

`tabata_screen.dart` — layout and gestures only, no business rules.
It borrows the controller from the session service and accepts a
`controller` parameter as a test seam. State is read inside a
`SignalBuilder` closure, and the session is claimed in `initState`, never
during build. Minimize = chevron-down in
the leading slot; ending the session = X in the actions, behind a confirm.

### 6. Route — `lib/routes/`

Add the name to `app_routes.dart` and the `GoRoute` to `app_pages.dart`,
then push it with `AppPages.push<T>(Routes.x, extra: …)` — which works from
controllers too, with no `BuildContext`.

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

**Signal reads must sit inside the `SignalBuilder` closure.** Reading
`x.value` in the enclosing `build` subscribes the widget to nothing; the
screen renders once and then freezes.

**Writing a signal during build throws.** Claim sessions in `initState`
and publish through `setAfterBuild()`.

**Tests get their own router and registrations.** `AppPages.createRouter()`
per pump, `setUpLocator()` in `setUp`, `resetLocator()` in `tearDown`.

**A session service outlives the widget tree.** The pending-timer check runs
before `addTearDown`, so any test that pumps a screen backed by a session
service must call `XSessionService().clear()` as the last statement of the
test body.

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
| **signals** | Fine-grained reactivity with the same mental model the code already used. Replaced GetX's state half. |
| **go_router** | The Flutter-team-endorsed router. Typed pushes, so the GetX cast crash cannot recur. |
| **get_it** | A service locator that does one thing. Lazy singletons replace `Get.lazyPut`. |

### State, routing and DI (migrated off GetX, 2026-08-26)

GetX used to cover state, routing, DI and dialogs in one package. It is
gone. Each part now has a single-purpose replacement, which is what makes
the pieces individually swappable:

| Concern | Package | Idiom |
| --- | --- | --- |
| State | **signals** | `signal(0)`, `listSignal<T>([])`, `SignalBuilder(builder: …)` |
| Routing | **go_router** | `AppPages.push<T>(Routes.x, extra: …)` |
| DI | **get_it** | `locator<XController>()`, registered in `services/locator.dart` |
| Messages / dialogs | Flutter | `UiMessenger()` holds the messenger and navigator keys |

Why signals over Riverpod: it maps one-to-one onto what the code already
wrote (`.obs` → `signal`, `Obx` → `SignalBuilder`), so the migration was
mechanical rather than architectural. The app's structure is unchanged;
only the reactive primitive is different.

**Use `SignalBuilder`, not `Watch`.** `Watch` is deprecated in signals 7,
and CI runs `analyze --fatal-infos`, so it fails the build.

#### Three rules the migration bought the hard way

**Read signals inside the builder closure.** `SignalBuilder` subscribes to
what its own closure touches. A read in the enclosing `build` subscribes to
nothing and the screen freezes.

**Never write a signal during build.** Claiming a session from a lazy field
read inside `build` marks already-mounted watchers dirty mid-build, which
Flutter rejects. Claim in `initState`, and publish through
`setAfterBuild()` (`utils/signal_scheduling.dart`), which defers one frame
when a build is already running. GetX tolerated this; signals is stricter,
and correctly so.

**Build a `GoRouter` per app, not one shared instance.** `AppPages.router`
is the app's; tests call `AppPages.createRouter()`. A reused router
restores the previous location, and a non-serializable `extra` comes back
as a decoded `Map` rather than the object that was pushed.

#### What `extra` costs

Route arguments travel in go_router's `extra`, which is not deep-link or
restoration safe. That is fine for an offline app with no deep links. If
that changes, routes should take an id in the path (`/timer/:id`) and the
screen should load the object — a bigger change, worth doing deliberately
rather than by accident.

### Gaps worth deciding on

| Gap | Recommendation |
| --- | --- |
| **No crash reporting** | Real gap for production. `sentry_flutter` is the usual pick and works offline-first (events queue until connectivity). Needs an account + DSN, so it is your call to make. |
| **Android toolchain warning** | The build warns that Kotlin 2.2.20 support "will soon be dropped" (needs ≥ 2.3.20); AGP is 8.11.1. Low urgency, but do it before it becomes forced. |
| **No release signing** | `android/app/build.gradle.kts` still signs release with the **debug** key. Must be fixed before any store upload — keystore + `key.properties`, both already gitignored. |
| **Test coverage not enforced** | CI uploads `lcov.info` but sets no floor. Add a threshold once coverage is measured. |

---

## Known sharp edges

**Route arguments are not type-checked.** go_router's `extra` is
`Object?`, so a route builder casting to the wrong type compiles fine and
fails when the page builds. `test/app_routes_test.dart` pins the argument
shape of every route that takes one.

> Historical note: the GetX version of this was worse — every named route
> was built as `GetPageRoute<dynamic>`, so `Get.toNamed<bool>` threw at
> runtime and pushes had to be untyped and narrowed by hand. `push<T>` is
> honest, so that whole workaround is gone.

**Theme text styles must agree on `inherit`.** `MaterialApp` lerps `ThemeData`
over ~200 ms on a theme switch, and `TextStyle.lerp` throws when two styles
disagree. Both themes derive their button styles from the same base for this
reason; `test/coffee_theme_test.dart` pumps mid-animation frames to prove it.

**The iOS Simulator MCP is broken on this machine.** Use:

```bash
flutter build ios --simulator --debug
```

then `xcrun simctl boot/install/launch` with bundle id
`dev.genexis.activitytimer`. Prefer widget tests over the simulator for
interactive flows.
