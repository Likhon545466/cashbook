# 🚀 CashBook Release Notes - v1.8.7 (Build 91)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.7-build91.apk`)

---

## 🌟 What's New in v1.8.7

### 1. 🔑 Restored Build 86 Signing Configuration & Google Sign-In
- **Exact Signing Key Restoration**: Restored the build signing configuration to match Build 86 perfectly.
- **Google Sign-In & Google Drive Cloud Sync**: Seamless Google Drive appDataFolder backups and cross-device restores.

### 2. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: Tapping "Install Update" prompts Android's system package installer directly without web redirects.
- **Added Permission**: `REQUEST_INSTALL_PACKAGES` permission in AndroidManifest.

### 3. ⚡ Optimized Update Link Matching & Resilient Download
- Guaranteed URL-encoded tag formatting and automatic retry actions if network hiccups occur.

---

## 🌟 Previous Features (v1.8.0 - v1.8.6)

- **In-App Streaming Progress Bar**: Download releases with live download speed (`MB/s`) and percentage counter.
- **Configurable Frequency**: Startup, Daily, Weekly, or Manual update checks in Settings.
- **Two-Tier Resilient Check**: GitHub REST API + rate-limit free Atom feed fallback.
- **Glassmorphic Popup Dialog & Radar Scanner**: Dedicated manual and automatic update check surfaces.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
