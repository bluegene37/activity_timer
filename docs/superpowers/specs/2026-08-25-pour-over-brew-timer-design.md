# Pour-over Brew Timer — Design

Date: 2026-08-25
Status: approved for planning

## Problem

A pour-over brew is a sequence of timed pours: bloom for 30–45s, then pour to a
cumulative water target every 30s or so until the recipe's total is reached, then
wait for drawdown. A brewing scale shows grams but has no timer, and a phone timer
shows seconds but not the target. The brewer ends up tracking both in their head.

Activity Timer already runs named, timed step sequences with audio cues, but its
models carry no notion of water, dose, or ratio, and nothing rescales when the
brewer changes how much coffee they are making.

## Goals

- Run a brew as timed steps that alarm at each boundary, the way a routine does.
- Show the cumulative water target for the current step as the primary readout.
- Rescale a whole recipe from two knobs: coffee dose and brew ratio.
- Ship well-known recipes, and let the user author and edit their own.
- Give the brew section its own visual identity (the genexis.dev washi palette).

## Non-goals

- Bluetooth scale integration. No hardware, no live weight reading.
- Brew logging, tasting notes history, or statistics.
- Espresso, cold brew, or immersion-only workflows beyond the AeroPress built-in.
- Restyling Activities, Intervals, or Settings. The washi theme is scoped to Brew.

## Data model

Four new Hive types in `lib/models/brew_recipe.dart`. Existing typeIds 0–7 are
taken (settings 0, ActivityTimer 1, TimerSequence 2, 3–4 interval, AlarmSound 5,
SessionHistory 6, IntervalPhase 7), so brew reserves 8–11.

```
BrewRecipe (typeId 8)
  id: String
  name: String
  method: BrewMethod          // v60 | chemex | kalita | aeropress | switch
  doseGrams: double           // 20.0
  ratio: double               // 16.0
  steps: List<BrewStep>
  alarmSoundName: String?
  notes: String?
  createdAt, updatedAt: DateTime

BrewStep (typeId 9)
  name: String                // "Bloom", "Second pour", "Drawdown"
  seconds: int                // length of this step
  pourToFraction: double?     // cumulative share of total water; null = no pour
  pourSeconds: int?           // length of the pour inside `seconds`
  kind: BrewStepKind          // (typeId 10) pour | wait | swirl | drawdown
  description: String?        // prose only, never a number that rescaling breaks

BrewMethod (typeId 11), BrewStepKind (typeId 10) — Hive enums
```

`BrewRecipe` is a pure Dart model: all brew math is computed, imports no Flutter
and touches no Hive box, so it is unit-testable without pumping a widget.

### Derived values

```
totalWater      = doseGrams * ratio
targetGrams(i)  = round(steps[i].pourToFraction * totalWater)
addGrams(i)     = targetGrams(i) - targetGrams(previous pour step)
pourRate(i)     = addGrams(i) / pourSeconds(i)        // g/s, shown as "≈4 g/s"
totalSeconds    = sum of step seconds
```

### Invariants (each gets a test)

1. `pourToFraction` is non-decreasing across steps; the editor rejects violations.
2. Targets round to whole grams for display.
3. The last pour step's target equals `totalWater` exactly — no drift from
   accumulated rounding. Computed by assigning the remainder to the final pour.
4. `0 < pourSeconds <= seconds` whenever `pourToFraction` is set.
5. `seconds > 0` for every step.

### Why fractions, not stored grams

Storing cumulative fractions makes rescaling one multiplication rather than a
per-step migration, and matches how a brewer works: watching the scale climb to a
number. Storing `doseGrams` and `ratio` separately (rather than a single total)
preserves the ratio the user dialed in when they brew a larger batch.

The editor takes and displays **grams**; it converts to a fraction on save
(`fraction = grams / totalWater`). Fractions never appear in the UI.

## Screens

### BrewListScreen (tab root)

Cards for saved brews: name, method, `20g · 1:16 · 320g · 3:00`, and a step
summary line ("4 pours · bloom 40g → 320g"). Row actions edit and delete; the card
body starts the brew. A "Brew Library" bottom sheet lists the built-ins and clones
one into the user's list, mirroring `ActivityListController.addPresetTemplate`
(`lib/controllers/activity_list_controller.dart:71`).

### BrewEditScreen

Name, method, dose, ratio, with a live total (`20g × 16 = 320g`). Below that the
step list: add, edit, reorder, delete. Per step: name, duration, pour target in
grams, pour seconds, description. Validation enforces the five invariants above
and blocks save with an inline message rather than a snackbar.

### BrewRunScreen

Strict auto-advance — no manual skip, no manual gate on drawdown.

- Cumulative target is the largest element on screen: **`pour to 100g`**.
- Below it: step name, `+60g · ≈4 g/s`, then the description line.
- Step countdown and total elapsed.
- During the pour window the screen reads **POUR** in the lead red; after
  `pourSeconds` elapses it reads **WAIT** in ink-soft, so the brewer knows to stop
  pouring while the step continues running.
- Next step previewed at the bottom ("next: pour to 160g").
- The recipe's `AlarmSound` fires at each step boundary, matching the Activity
  Timer. No cue at the POUR → WAIT flip.
- Wakelock held for the duration, as in `lib/screens/timer_screen.dart`.

## Controllers

- `BrewController` — list state and CRUD against the database service.
- `BrewRunController` — the running clock, step advancement, cue playback, and
  wakelock. Kept separate so timing logic is testable without a list or a box.

Both follow the existing GetX patterns: `Rx` fields, `Get.lazyPut` bindings in the
route table, `Get.snackbar` for failures.

## Persistence

A `brew_recipes` box added to `lib/services/database_service.dart`, with CRUD
methods mirroring the interval-timer ones, plus a pure `getBrewTemplates()` that
returns the built-ins from code (no box), exactly like `getPresetTemplates()`.

### Built-in recipes

Starting values; the brewer rescales by dose. Fractions are cumulative.

| Recipe | Dose / ratio | Steps |
|---|---|---|
| Hoffmann V60 | 30g / 1:16.7 (500g) | bloom→0.12 (45s, pour 10s), →0.60 (45s, pour 30s), →1.00 (30s, pour 30s), swirl (10s), drawdown (95s) |
| Kasuya 4:6 | 20g / 1:15 (300g) | five pours →0.2 →0.4 →0.6 →0.8 →1.0, 45s each with 10s pours, drawdown (45s) |
| Chemex | 30g / 1:16.7 (500g) | bloom→0.12 (45s), →0.50 (45s), →0.76 (45s), →1.00 (45s), drawdown (90s) |
| Kalita Wave | 20g / 1:16 (320g) | bloom→0.1875 (30s), →0.50 (30s), →0.75 (30s), →1.00 (30s), drawdown (60s) |
| AeroPress | 11g / 1:18.2 (200g) | pour→1.00 (15s), wait (120s), swirl (10s), wait (30s), press (30s) |

## Navigation and routes

A fourth tab in `lib/navigation/main_navigation.dart`, ordered **Activities ·
Intervals · Brew · Settings** so existing tab positions are undisturbed. Icons:
`Icons.coffee_outlined` / `Icons.coffee`. The tab's floating action button reads
"New Brew", alongside the existing New Routine and New Interval buttons.

Two routes in `lib/routes/app_routes.dart` and `app_pages.dart`:

- `/edit-brew` — arguments record `({BrewRecipe recipe, bool isNew})`
- `/brew` — argument `BrewRecipe`

Both are pushed with `Get.toNamed<dynamic>`. GetX's route generator always builds
`GetPageRoute<dynamic>`, so a concrete type argument throws a cast error inside
`Navigator.pushNamed` — the crash fixed earlier in
`lib/controllers/interval_timer_controller.dart`.

## Theme

`lib/theme/brew_theme.dart` holds the genexis.dev tokens and builds a `ThemeData`
that reuses `AppTheme`'s radii and 8pt spacing constants, so the layout grammar
matches the rest of the app while the palette and typography differ.

Light (taken from genexis.dev):

```
paper        #F2EDE3     ink          #16161A
paper-raised #FAF7F0     ink-soft     #5A564E
paper-deep   #E7E0D0     graphite     #66625A
paper-recess #DED6C4     lead         #B4402C
hairline     rgba(43,43,46,.18)       lead-deep    #8E3122
```

Dark (derived; the site is light-only):

```
paper        #1B1815     ink          #F2EDE3
paper-raised #241F1B     ink-soft     #B8B0A2
paper-deep   #15120F     lead         #D9614A
```

Typography is Literata, matching the site: headings at weight 400 with tight
tracking (about -1.9px at display size). The app is offline and has no
`google_fonts`, so Literata ships as a bundled asset (Regular + SemiBold,
roughly 300–400KB) declared in `pubspec.yaml`. Without it the section falls back
to Georgia/serif.

The theme wraps only the Brew subtree. No other screen changes.

## Testing

- **Unit, no Flutter**: scaling math; whole-gram rounding; final target equals
  total water exactly; non-decreasing validation; `pourSeconds <= seconds`;
  g/s derivation; total duration; built-in templates parse and satisfy every
  invariant.
- **Widget**: list renders saved brews and clones from the library; editor blocks
  each invalid case; runner advances through steps under `tester.pump`, fires a
  cue at each boundary, and flips POUR → WAIT at `pourSeconds`. Uses the
  `audioplayers` and `wakelock_plus` channel mocks from
  `test/timer_screen_test.dart`.
- **Route contract**: `/edit-brew` and `/brew` argument records added to
  `test/app_routes_test.dart`.

`flutter analyze && flutter test` must pass; `analysis_options.yaml` enables
`strict-casts`, `strict-inference`, and `strict-raw-types`.

## Risks

- **Hive typeIds** must not collide with future models; 8–11 are reserved here.
- **App size** grows by the bundled font.
- **Scope creep** toward brew logging and scale integration; both are non-goals.
- The change is otherwise additive: no existing model, box, screen, or route is
  modified, so routines and interval timers are unaffected.

## Out of scope, possible later

- A soft cue at the POUR → WAIT flip.
- Manual advance or a drawdown step that waits for a tap.
- Brew history and tasting notes.
