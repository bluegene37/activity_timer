# Security Policy

## Supported Versions

We provide security updates and patches for the following versions of **Activity Timer**:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0.0 | :x:                |

---

## 🛡️ Security & Privacy Architecture

Activity Timer is intentionally designed with an **offline-first, zero-trust privacy posture**:

1. **No External Network Calls**:
   - The application does not declare internet permissions on Android (`android.permission.INTERNET` is omitted from `AndroidManifest.xml`).
   - No remote API endpoints, background tracking pings, or telemetry beacons are present.

2. **Local Sandboxed Storage**:
   - All user routines, intervals, custom pour-over recipes, and timer logs are stored exclusively in the app's sandboxed filesystem using [Hive CE](https://github.com/isar/hive_ce).
   - Data is never synchronized or backed up to untrusted cloud servers unless initiated by the OS-level system backup.

3. **Privacy Compliance**:
   - iOS builds include a verified Apple Privacy Manifest (`ios/Runner/PrivacyInfo.xcprivacy`) certifying that no tracking domains, fingerprinting APIs, or personal data collection types are accessed.
   - Compliant with Google Play Data Safety policies for zero data collection.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or privacy flaw within Activity Timer, please do **NOT** open a public issue.

Instead, please report it responsibly:

1. **GitHub Security Advisory**:
   Submit a private report via the [GitHub Security Advisory](https://github.com/genexis-dev/activity_timer/security/advisories/new) dashboard.

2. **Direct Email**:
   Email our maintainer team directly at [security@genexis.dev](mailto:security@genexis.dev).

### What to Include
- A detailed description of the vulnerability and potential impact.
- Clear steps to reproduce (or a minimal Proof of Concept).
- Details regarding target platform (Android / iOS version, device model).

### Response Timeline
- **Initial Acknowledgement**: Within 48 hours.
- **Triage & Assessment**: Within 5 business days.
- **Fix & Disclosure**: Coordinated release and credit attribution upon verification.
