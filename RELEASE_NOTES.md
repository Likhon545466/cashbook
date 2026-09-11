# 🚀 CashBook Release Notes - v1.8.8 (Build 92)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.8-build92.apk`)

---

## 🌟 What's New in v1.8.8

### 1. 🔑 Google OAuth 2.0 Web Client ID Integration & Cloud Sync
- **OAuth Web Client ID Fix**: Configured the official Google Cloud Console Web Application Client ID (`879746739863-af2rv6mstrptpisldkds70ic9rcd0ju1.apps.googleusercontent.com`) to ensure seamless Google Play Services authentication for Drive scopes on Android.
- **Legacy ID Auto-Migration**: Added automatic detection and migration in `CloudSyncProvider` for any legacy Android Client ID stored in local settings.
- **Verified Cloud Backup & Restore**: Robust Google Drive `appDataFolder` backup, metadata sync, and cross-device restore.

### 2. 🔑 Retained Build 86 Signing Key
- **Signature Compatibility**: Retained the original signing keystore configuration (`01:D1:FE:DE:79:81:2C:DA:86:24:16:40:77:41:FD:9C:8F:D3:7E:A8`) so in-place upgrades and Google Sign-In match without signature collisions.

### 3. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: 1-tap in-app APK installer with `REQUEST_INSTALL_PACKAGES` permission.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `dart analyze`.
