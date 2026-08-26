# Releasing Activity Timer

Platforms shipped: **Android** (Play Store, `.aab`) and **iOS** (App Store,
`.ipa`). There are no desktop or web targets.

App identity, fixed everywhere:

| | |
| --- | --- |
| Display name | Activity Timer |
| Bundle / application ID | `dev.genexis.activitytimer` |
| Publisher | genexis.dev |
| Copyright | Copyright © 2026 genexis.dev. All rights reserved. |

## Versioning

`pubspec.yaml` `version: X.Y.Z+N` is the **single source of truth**. One
exception must be bumped by hand alongside it:

- `lib/screens/settings_screen.dart` — the hardcoded version string in the
  Settings → About section. (Switching it to `package_info_plus` would
  remove this step, at the cost of a new platform-channel dependency and
  test mocks.)

Everything else reads pubspec automatically:

- Android reads `flutter.versionName` / `flutter.versionCode` in
  `android/app/build.gradle.kts`.
- iOS reads `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` in
  `ios/Runner/Info.plist`. (The `MARKETING_VERSION` in `project.pbxproj` is
  unused — Info.plist wins.)

Rules:

- `X.Y.Z` is the user-visible semantic version and must match the git tag
  (`v X.Y.Z`); the release workflow fails if they disagree.
- `+N` is the store build number. It must **increase monotonically forever**
  — both stores reject a reused build number, even across versions. Never
  decrease it, never reuse it, bump it for *every* store upload including
  re-uploads of the same X.Y.Z.

## Release flow (tag push)

```bash
# 1. Bump version in pubspec.yaml (e.g. 1.1.0+2), commit.
# 2. Tag and push — this triggers .github/workflows/release.yml:
git tag v1.1.0
git push origin main v1.1.0
```

CI then runs analyze + tests, builds both platforms, and attaches artifacts
to a GitHub release:

- `activity-timer-<version>.aab` + `symbols-android.zip`
- `Runner-<version>.xcarchive.zip` (unsigned) + `symbols-ios.zip`

The CI `.aab` is **debug-signed unless** the `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` secrets are configured
(base64 of the keystore: `base64 -i upload-keystore.jks`). The CI iOS build
is unsigned — the store `.ipa` is produced locally (below). Store uploads
themselves are manual: Play Console for the `.aab`, Transporter/Xcode
Organizer for the `.ipa`.

## Local release builds

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
# → build/app/outputs/bundle/release/app-release.aab

flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
# → build/ios/ipa/*.ipa
```

**Archive `build/symbols/` for every store upload** — without those files,
production crash stacks are unreadable and they cannot be regenerated.

## Signing status

| Platform | Status |
| --- | --- |
| Android | `android/app/build.gradle.kts` reads `android/key.properties` (gitignored). Copy `android/key.properties.example`, generate the keystore with the `keytool` command in it, and **back the keystore up somewhere durable** — losing it means losing the ability to update the app on Play. Without `key.properties` release builds fall back to debug signing so `flutter run --release` still works. |
| iOS | Xcode automatic signing, team `8AD458D2K2`. The Apple team must be selected manually in Xcode (Runner target → Signing & Capabilities) on any new machine; certs cannot be checked in. |

## Pre-release checklist

- [ ] `pubspec.yaml` version bumped; build number `+N` never used before
- [ ] Settings → About version string bumped to match (`lib/screens/settings_screen.dart`)
- [ ] `flutter analyze && flutter test` clean
- [ ] Android SDK licenses accepted (`flutter doctor --android-licenses` — interactive, run it yourself)
- [ ] Both release builds succeed locally with `--obfuscate`; `build/symbols/` archived
- [ ] Release build smoke-tested on a real device (timers fire from background / after reboot)
- [ ] Store listing text current: [docs/STORE_LISTING.md](docs/STORE_LISTING.md)
- [ ] Play Data safety + App Store privacy answers still "no data collected" (see STORE_LISTING.md); `ios/Runner/PrivacyInfo.xcprivacy` still accurate
- [ ] Tag matches pubspec version; tag pushed; GitHub release artifacts present
- [ ] Play: staged rollout at a low percentage first — an App Store release cannot be pulled back, only superseded
