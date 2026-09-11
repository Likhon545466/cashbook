# 🚀 CashBook Release Notes - v1.8.0 (Build 84)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.0-build84.apk`)

---

## 🌟 What's New in v1.8.0

### 1. 🔄 In-App GitHub Release Update System
- **Two-Tier Resilient Check**: Automatically checks GitHub REST API for new releases, with an instant rate-limit-free fallback to `releases.atom` and raw repository version files (`.cashbook_version`, `pubspec.yaml`).
- **Direct 1-Tap APK Downloads**: Constructs direct download links with properly URL-encoded release tags (`+` as `%2B`) to guarantee seamless downloads without 404 errors.
- **Accurate Build Number & Semantic Comparison**: Correctly detects newer versions even across build numbers.

### 2. 🚀 Automatic Startup Update Popup Dialog
- **Non-Blocking Background Check**: Checks silently ~2.2s after app startup so opening the app remains lightning fast.
- **Glassmorphic Presentation**: Clean glass card layout displaying current version vs new version pills, release date, formatted APK size chips, and scrollable release notes.
- **Quick Action Buttons**: 1-tap **"Download APK"**, **"GitHub Release"**, or **"Later"**.

### 3. 🔍 Interactive Update Checker Modal in Settings
- **Animated Radar Scanner**: Dedicated manual update checker in Settings and About hub featuring animated pulse waves.
- **Up-to-Date & Recovery States**: Clean status indicators with last-checked timestamp, error recovery retry button, and direct GitHub links.

---

## 🛠 Quality & Performance Improvements
- 🧪 **100% Test Coverage**: All 80 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
- 🔒 **Enhanced Data Integrity**: Safe database transactions, cloud sync resilience, and isolated monthly ledgers.
