# activity_timer

Offline activity and interval timer (Flutter). Stack: GetX for state and
routing, Hive CE for persistence, `audioplayers` for cues, `wakelock_plus` to
keep the screen awake during a running timer.

Layout: `lib/{models,controllers,services,screens,components,navigation,routes,theme,utils}`,
widget and unit tests in `test/` (12 files).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the layer rules, the
step-by-step playbook for adding a feature, the Hive type-id table, and the
dependency review.

## Skills

Invoke these without being asked — they match how this project is actually worked on:

- **`flutter-testing`** — any time you write, fix, or triage a test. This is the
  default mode of work here; nearly every change lands with a widget test.
- **`flutter-quality`** — for jank, rebuild churn, accessibility, analyzer/lint
  config, or app-size work.
- **`flutter-architecture`** — before adding a new layer, controller, service,
  or route, or when restructuring existing ones.
- **`flutter-release`** — for versioning, signing, store builds, or CI.

## Verification

Both must pass before claiming a change is done:

```bash
flutter analyze && flutter test
```

`flutter analyze` is not optional here — `analysis_options.yaml` enables
`strict-casts`, `strict-inference`, and `strict-raw-types`, so type slop that
other Flutter projects tolerate fails this one.

House lints to write to, not fight: single quotes, `prefer_final_locals`,
`always_declare_return_types`, `sort_constructors_first`, `unawaited_futures`,
`use_super_parameters`, `directives_ordering`. Generated `*.g.dart` is excluded
from analysis — regenerate it rather than hand-editing.

## Running on iOS simulator

The iOS Simulator MCP (`attach`/`launch`) is broken on this Mac — it reports a
bad `xcode-select` even though the path is correct. There is no tap injection
available either (no cliclick/idb/applesimutils, and `osascript` lacks
assistive access). Instead:

```bash
flutter build ios --simulator --debug
```

then `xcrun simctl boot/install/launch` with bundle id
`dev.genexis.activitytimer`, and `xcrun simctl io <udid> screenshot` for
headless screenshots.

For interactive flows, prefer widget tests over the simulator. See
`test/timer_screen_test.dart` for the `audioplayers` and `wakelock_plus`
platform-channel mocks (`test/settings_screen_test.dart` mocks `audioplayers`
only).
