# 🚀 CashBook Release Notes - v1.8.4 (Build 88)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.4-build88.apk`)

---

## 🌟 What's New in v1.8.4

### 1. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: The "Install Update" button now directly opens the Android system package installer dialog (`application/vnd.android.package-archive` with read permissions), eliminating any unwanted browser redirect loops.
- **Added Permission**: Added `REQUEST_INSTALL_PACKAGES` to AndroidManifest.

### 2. 🔑 Unified Release Signing Keystore
- **Eliminated Package Conflict Error**: Release builds are now signed with a consistent project release keystore across local builds and CI/CD pipelines. This ensures updates install in-place without "Package conflicts with an existing package" errors.

### 3. ⚡ Optimized Update Link Matching & Resilient Download
- Guaranteed URL-encoded tag formatting and automatic retry actions if network hiccups occur.

---

## 🌟 Previous Features (v1.8.0 - v1.8.3)

- **In-App Streaming Progress Bar**: Download releases with live download speed (`MB/s`) and percentage counter.
- **Configurable Frequency**: Startup, Daily, Weekly, or Manual update checks in Settings.
- **Two-Tier Resilient Check**: GitHub REST API + rate-limit free Atom feed fallback.
- **Glassmorphic Popup Dialog & Radar Scanner**: Dedicated manual and automatic update check surfaces.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
