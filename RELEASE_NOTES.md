# 🚀 CashBook Release Notes - v1.8.6 (Build 90)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.6-build90.apk`)

---

## 🌟 What's New in v1.8.6

### 1. 🔑 Google Sign-In & Google Cloud OAuth Integration
- **Verified Google Sign-In on Release Builds**: The release signing certificate is aligned with Google Cloud Console OAuth 2.0 Client credentials (`01:D1:FE:DE:79:81:2C:DA:86:24:16:40:77:41:FD:9C:8F:D3:7E:A8`).
- **Google Drive Cloud Sync**: Seamless Google Drive appDataFolder backups and cross-device restores with end-to-end AES-256 encryption.

### 2. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: Tapping "Install Update" prompts Android's system package installer directly without browser redirects.
- **Added Permission**: `REQUEST_INSTALL_PACKAGES` permission in AndroidManifest.

### 3. ⚡ Optimized Update Link Matching & Resilient Download
- Guaranteed URL-encoded tag formatting and automatic retry actions if network hiccups occur.

---

## 🌟 Previous Features (v1.8.0 - v1.8.5)

- **In-App Streaming Progress Bar**: Download releases with live download speed (`MB/s`) and percentage counter.
- **Configurable Frequency**: Startup, Daily, Weekly, or Manual update checks in Settings.
- **Two-Tier Resilient Check**: GitHub REST API + rate-limit free Atom feed fallback.
- **Glassmorphic Popup Dialog & Radar Scanner**: Dedicated manual and automatic update check surfaces.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
