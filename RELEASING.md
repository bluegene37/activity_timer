# Releasing Activity Timer

This guide details the release architecture, versioning rules, signing requirements, and automated release pipelines for **Activity Timer**.

## 📱 Shipped Platforms & Application Identity

| Attribute | Value |
|---|---|
| **Supported Platforms** | Android (Google Play Store, `.aab`, `.apk`), iOS (Apple App Store, `.ipa`, `.xcarchive`) |
| **Application / Bundle ID** | `dev.genexis.activitytimer` |
| **Display Name** | Activity Timer |
| **Publisher** | genexis.dev |
| **Copyright** | Copyright © 2026 genexis.dev. All rights reserved. |

---

## 🔢 Versioning Architecture

The application uses **Semantic Versioning** (`X.Y.Z`) combined with a build number (`+N`).

`pubspec.yaml` `version: X.Y.Z+N` is the **single source of truth**.

When bumping a version, synchronize these locations:
1. `pubspec.yaml`: Update `version: X.Y.Z+N` (e.g., `1.0.0+1`).
2. `lib/screens/settings_screen.dart`: Update the display string in the Settings → About card (`'X.Y.Z'`).
3. `CHANGELOG.md`: Move staged items under `## [X.Y.Z] - YYYY-MM-DD`.

### Platform Mapping
- **Android**: Automatically consumes `flutter.versionName` (`X.Y.Z`) and `flutter.versionCode` (`N`) via `android/app/build.gradle.kts`.
- **iOS**: Automatically consumes `$(FLUTTER_BUILD_NAME)` and `$(FLUTTER_BUILD_NUMBER)` via `ios/Runner/Info.plist`.

### Invariant Rules
- **Semantic Version (`X.Y.Z`)**: Must match the release git tag exactly (e.g., `v1.0.0`). The CI release pipeline validates this match and aborts if inconsistent.
- **Build Number (`+N`)**: Must **monotonically increase forever**. Both Google Play Console and Apple App Store Connect reject duplicate or lower build numbers. Never reuse or decrement `N`.

---

## 🔐 Code Signing Setup

### Android Signing (Google Play)

Android release builds look for `android/key.properties` (which is gitignored).

1. Copy the example configuration:
   ```bash
   cp android/key.properties.example android/key.properties
   ```
2. Generate an upload keystore:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. Update `android/key.properties` with the path and passwords:
   ```properties
   storePassword=your-keystore-password
   keyPassword=your-key-password
   keyAlias=upload
   storeFile=/path/to/upload-keystore.jks
   ```
4. **CI Secrets**:
   To enable automatic release signing and Play Store deployment in GitHub Actions, configure repository secrets:
   - `ANDROID_KEYSTORE_BASE64` (generated via `base64 -i upload-keystore.jks`)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_KEY_ALIAS` (optional, defaults to `upload`)
   - `PLAY_SERVICE_ACCOUNT_JSON` (Google Play service account JSON key with release management permissions)

*(Note: Without `key.properties` present, local builds fall back to debug keys so `flutter run --release` continues to work seamlessly.)*

### iOS Signing (Apple App Store)

iOS signing uses Xcode Automatic Signing with Team ID `8AD458D2K2`.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Under **Runner Target** → **Signing & Capabilities**, select your provisioned Apple Developer Team.
3. CI builds produce unsigned archives (`.xcarchive.zip`). Signed distribution IPAs are built on local release machines via `flutter build ipa --release`.

---

## 🛠️ Release Execution Workflow

### 1. Automated Tagged Release (Recommended)

1. Verify all tests and static analysis pass locally:
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```
2. Update versions in `pubspec.yaml`, `lib/screens/settings_screen.dart`, and `CHANGELOG.md`.
3. Commit and tag:
   ```bash
   git add pubspec.yaml lib/screens/settings_screen.dart CHANGELOG.md
   git commit -m "chore(release): prepare v1.0.0"
   git tag v1.0.0
   git push origin main v1.0.0
   ```
4. **GitHub Actions** will automatically:
   - Validate that tag `v1.0.0` matches `pubspec.yaml` version `1.0.0`.
   - Run tests and static analysis with `--fatal-infos`.
   - Build Android `.aab` bundle and standalone `.apk` + symbols archive.
   - If `PLAY_SERVICE_ACCOUNT_JSON` is configured, automatically deploy the `.aab` to the Google Play Internal track.
   - Build iOS `.xcarchive.zip` + symbols archive.
   - Publish a GitHub Release with attached binaries and auto-generated release notes.

---

### 2. Fast-Track Google Play Internal Testing (Manual Workflow)

For pushing internal testing builds directly to Google Play without creating a git release tag:
1. Go to **Actions** → **Deploy to Google Play Internal Testing** in GitHub.
2. Click **Run workflow**.
3. Choose whether `auto_increment_build` should be enabled (default: `true`, which assigns build number `10 + run_number` to avoid version code collisions on Google Play).
4. GitHub Actions will test, build, and deploy the `.aab` straight to the Google Play **Internal** testing track.

---

### 3. Local Release Builds

#### Android Bundle & APK
```bash
# Android App Bundle for Play Store upload:
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android

# Standalone APK for sideloading / testing:
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

#### iOS IPA & Archive
```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols/ios
```

> [!WARNING]
> **Always save and archive `build/symbols/`** for every published build. De-obfuscating crash logs from production without the corresponding symbols is impossible.

---

## ✅ Pre-Release Quality Checklist

Prior to triggering a production release, ensure the following checklist is completed:

- [ ] **Version Synchronization**: `pubspec.yaml` version bumped; build number `+N` has never been used before.
- [ ] **About Screen**: Hardcoded version string updated in `lib/screens/settings_screen.dart`.
- [ ] **Changelog**: `CHANGELOG.md` updated with all notable changes under the target version header.
- [ ] **Quality Gates**: `flutter analyze --fatal-infos` and `flutter test` both pass 100% clean.
- [ ] **Code Formatting**: `dart format --set-exit-if-changed lib test` reports zero changes.
- [ ] **Privacy Verification**: `ios/Runner/PrivacyInfo.xcprivacy` and Google Play Data Safety forms reflect zero data collection.
- [ ] **Smoke Test on Device**: Active timers fire from background, alarms ring, and wake lock behaves as expected.
- [ ] **Symbols Archived**: Obfuscation symbols saved to durable storage for crash diagnosis.
- [ ] **Staged Rollout**: On Google Play, deploy initially to Internal Testing or 10% Production rollout.
