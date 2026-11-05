# Activity Timer — iOS App Store Production Release Guide

This document provides complete, step-by-step instructions for launching **Activity Timer** in production on the Apple App Store.

---

## 📋 Release Summary & Identity

| Attribute | Value |
|---|---|
| **App Name** | `Activity Timer` (14 / 30 chars) |
| **Subtitle** | `Interval, routine & brew timer` (30 / 30 chars) |
| **Bundle ID** | `dev.genexis.activitytimer` |
| **Release Version** | `1.0.3` |
| **Git Tag** | `v1.0.3` |
| **Apple Developer Team** | `T7LB768N2Z` |
| **Device Family** | Universal (`iPhone` & `iPad`) |
| **Minimum OS** | iOS 15.0 |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Productivity |
| **Age Rating** | 4+ |
| **Privacy Policy URL** | `https://genexis.dev/privacy` |
| **Support URL** | `https://genexis.dev` (Email: `support@genexis.dev`) |
| **Marketing URL** | `https://genexis.dev` |

---

## 🎨 Production Screenshots Prepared

Ready-to-upload screenshot packages formatted strictly to Apple App Store Connect specifications:

- **iPhone 6.7" / 6.9" Super Retina (1290 × 2796 px, 24-bit RGB PNG, Zero Alpha):**  
  `~/Documents/personal_projects/screenshots/activity_timer/ios_app_store/iphone/` (Files `1.png` to `10.png`)
- **iPad Pro 13" Display (2064 × 2752 px, 24-bit RGB PNG, Zero Alpha):**  
  `~/Documents/personal_projects/screenshots/activity_timer/ios_app_store/ipad/` (Files `1.png` to `10.png`)

---

## 🚀 Execution Steps

### Step 1: Pre-Release Quality Check
Verify code formatting, static analysis, and unit/widget test suite:
```bash
# Verify static analysis (0 errors, 0 warnings, 0 infos)
flutter analyze --fatal-infos

# Run full test suite (203 passing tests)
flutter test
```

### Step 2: Trigger Automated CI Release Pipeline
Dispatch the GitHub Actions production release workflow from terminal:
```bash
# Build, sign with Apple Distribution Profile, and upload directly to App Store Connect / TestFlight:
gh workflow run release.yml -f platform=ios
```

To monitor the workflow in real time:
```bash
gh run watch
```

*(Note: The CI automatically signs the archive, extracts debug symbols for crash reporting, and uploads the `.ipa` to App Store Connect).*

---

## 🖥️ Step 3: App Store Connect Final Submission (Web Console)

Once the GitHub Actions build finishes and Apple finishes processing the build (typically 5–15 minutes):

1. **Log in to App Store Connect:**  
   Navigate to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps).

2. **Select Activity Timer:**  
   Click on **Activity Timer** (`dev.genexis.activitytimer`).

3. **Create or Open Version 1.0.3:**  
   - Under iOS App on the left sidebar, verify **1.0.3 Prepare for Submission** is selected.

4. **Upload Screenshots:**  
   - Drag & drop `~/Documents/personal_projects/screenshots/activity_timer/ios_app_store/iphone/` (`1.png` through `10.png`) into the **6.7" / 6.9" Display** slot.  
   - Drag & drop `~/Documents/personal_projects/screenshots/activity_timer/ios_app_store/ipad/` (`1.png` through `10.png`) into the **13" iPad Display** slot.

5. **Enter Metadata:**  
   - **Promotional Text / Subtitle:** `Interval, routine & brew timer`  
   - **Keywords:** `timer,interval timer,workout timer,hiit,tabata,routine,coffee timer,pour over,study,fitness timer`  
   - **Support URL:** `https://genexis.dev`  
   - **Marketing URL:** `https://genexis.dev`  
   - **Description:** Copy from `store/store_listing.md`.

6. **Select the Uploaded Build:**  
   - Scroll down to the **Build** section.  
   - Click **+ Select Build**, choose version `1.0.3` (with the auto-incremented build number from CI), and click **Done**.  
   - When asked about **Export Compliance**, select **Yes** (uses encryption) and then **Yes** (exempt encryption), or confirm standard exemption.

7. **App Review Information:**  
   - **Sign-In Required:** Leave **Unchecked** (App is 100% offline, zero accounts).  
   - **Contact Information:** Enter your Name, Phone Number, and `support@genexis.dev`.  
   - **Notes:**  
     > "Activity Timer is an offline utility timer. All routines, intervals, and pour-over timers operate completely offline without user accounts or external network connectivity. Sound cues and timer transitions trigger both in-foreground and via local notifications when backgrounded."

8. **Submit for Review:**  
   - Click **Save** in the top right.  
   - Click **Add for Review**, then click **Submit to App Review**.

---

## 📈 Step 4: Release Options

Under **Version Release**:
- Select **Manually release this version** (recommended) so you control the exact moment the app goes live after Apple approval, or **Automatically release this version**.
