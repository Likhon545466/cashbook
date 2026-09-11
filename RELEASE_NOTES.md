# 🚀 CashBook Release Notes - v1.8.2 (Build 86)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.2-build86.apk`)

---

## 🌟 What's New in v1.8.2

### 1. 📥 In-App Download Progress & Direct Native Installer
- **Live Streaming Progress Bar**: Download releases directly within CashBook with animated progress, live speed calculation (`MB/s`), downloaded vs total megabytes display, and cancelability.
- **Direct Package Installer Launch**: Automatically opens the native Android package installer when download finishes, with resilient fallback to the external browser if needed.

### 2. ⚙️ Configurable Auto-Update Check Frequency
- **Customizable Intervals**: Choose background update check frequency in Settings under **About & Updates**:
  - `Every Startup` (default)
  - `Once Daily` (24-hour interval)
  - `Once a Week` (7-day interval)
  - `Manual Only`
- **SQLite State Persistence**: Saves preferences and last-checked timestamps across app reboots.

### 3. 🤖 Automated GitHub Actions Release Workflow
- **Continuous Integration & Delivery**: Automated `.github/workflows/release.yml` triggers on tag push (`v*`), executes `flutter analyze` and `flutter test`, builds optimized release APKs, generates SHA-256 checksums, and publishes GitHub releases automatically.

---

## 🌟 Previous Features (v1.8.0 - v1.8.1)

- **Two-Tier Resilient Check**: GitHub REST API + raw repository / Atom feed rate-limit bypass.
- **Glassmorphic Startup Dialog**: Non-blocking popup alerting users to new releases.
- **Interactive Radar Checker**: Manual update scanner modal with pulse wave animations in Settings.
- **URL-Encoded Release Assets**: Safe `%2B` encoding for trouble-free downloads.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
