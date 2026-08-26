# Store listing — Activity Timer

Copy-paste source for App Store Connect and the Play Console. Character
limits are noted per field; counts here are within them.

## Identity

| Field | Value |
| --- | --- |
| App name (both stores, 30 chars) | Activity Timer |
| Bundle / application ID | `dev.genexis.activitytimer` |
| Publisher / developer name | genexis.dev |
| Copyright | Copyright © 2026 genexis.dev. All rights reserved. |
| Category | Productivity (secondary: Health & Fitness) |
| Price | Free |
| Version | 1.0.0 (build 1) |

## iOS subtitle (30 chars)

> Interval, activity, brew timer

## Play short description (80 chars)

> Offline activity, interval, and pour-over coffee timers. No ads, no tracking.

## Full description (both stores)

> Activity Timer is a simple, fully offline timer for the things you
> actually do: workouts, chores, focus blocks, and pour-over coffee.
>
> **Activity timers** — one-tap countdown timers for recurring tasks.
> Name them, pick a sound, and reuse them every day.
>
> **Interval timers** — build multi-phase routines (work / rest / repeat)
> and loop them for as many rounds as you need. The screen stays awake
> while a timer runs, and audio cues mark every phase change.
>
> **Coffee brew timers** — step-by-step pour-over recipes with timed
> pours, so every brew comes out the same.
>
> **Session history** — see what you finished and when.
>
> **Private by design** — everything is stored on your device. No
> account, no internet permission, no ads, no analytics, no tracking.
> Timer alarms fire as exact local notifications, even if the app is in
> the background or the phone was rebooted.

## Keywords (iOS, 100 chars)

> interval,timer,hiit,workout,tabata,pomodoro,pour over,coffee,brew,routine,offline,countdown

## Privacy answers

The app collects **no data**. It has no network access and no
third-party SDKs that phone home.

- **App Store privacy questionnaire**: "Data Not Collected" for every
  category. `PrivacyInfo.xcprivacy` in the repo declares no tracking and
  no collected data types.
- **Play Data safety form**: No data collected, no data shared, data is
  not encrypted in transit (none is transmitted), users cannot request
  deletion (nothing leaves the device).
- **Export compliance**: `ITSAppUsesNonExemptEncryption` is `false` in
  `Info.plist` — no custom encryption.

## Permission justifications (review notes)

- `POST_NOTIFICATIONS` / iOS notification prompt — sounds the alarm when
  a timer finishes.
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` — a timer that fires a
  minute late is useless; alarms must fire at the exact scheduled second.
- `RECEIVE_BOOT_COMPLETED` — restores pending timer alarms after a
  reboot.
- `VIBRATE` — haptic feedback with the alarm.

## Assets still needed (cannot be generated from the repo)

- Screenshots: iPhone 6.9" and 6.5" (App Store), phone + 7" and 10"
  tablet (Play).
- Play feature graphic, 1024×500.
- Privacy policy URL — both stores require one even for a no-data app.
  A one-page "this app collects nothing" statement hosted anywhere
  (e.g. GitHub Pages) is sufficient.
- Support URL / support email.
