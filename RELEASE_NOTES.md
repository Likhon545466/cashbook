# 🚀 CashBook Release Notes - v1.8.5 (Build 89)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.5-build89.apk`)

---

## 🌟 What's New in v1.8.5

### 1. 🔑 Google Sign-In & Google Cloud OAuth Certificate Alignment
- **Fixed Google Login on Release Builds**: Aligned the unified project release signing certificate with the authorized SHA-1 fingerprint registered in Google Cloud Console (`01:D1:FE:DE:79:81:2C:DA:86:24:16:40:77:41:FD:9C:8F:D3:7E:A8`).
- **Restored Cloud Sync & Drive Backup**: Google Drive cloud backups, auto-sync, and restore now authenticate smoothly across both local and GitHub Actions release builds without OAuth certificate mismatch errors.

### 2. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: Tapping "Install Update" prompts Android's system package installer directly without web redirects.
- **Added Permission**: `REQUEST_INSTALL_PACKAGES` permission in AndroidManifest.

### 3. ⚡ Optimized Update Link Matching & Resilient Download
- Guaranteed URL-encoded tag formatting and automatic retry actions if network hiccups occur.

---

## 🌟 Previous Features (v1.8.0 - v1.8.4)

- **In-App Streaming Progress Bar**: Download releases with live download speed (`MB/s`) and percentage counter.
- **Configurable Frequency**: Startup, Daily, Weekly, or Manual update checks in Settings.
- **Two-Tier Resilient Check**: GitHub REST API + rate-limit free Atom feed fallback.
- **Glassmorphic Popup Dialog & Radar Scanner**: Dedicated manual and automatic update check surfaces.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
