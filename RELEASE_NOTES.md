# 🚀 CashBook Release Notes - v1.8.9 (Build 93)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.9-build93.apk`)

---

## 🌟 What's New in v1.8.9

### 1. 🔑 Exact Build 86 Google Authentication Parity
- **Restored Build 86 Configuration**: Restored the exact Google Client ID configuration (`879746739863-9l6eks9fvu0jg0d194mejg4p8cg7i12g.apps.googleusercontent.com`) and authentication flow that operated cleanly in Build 86.
- **Drive AppData Sync**: Preserved full Google Drive `appDataFolder` sync and restore capability.

### 2. 🔐 Bundled Keystore for GitHub Actions CI/CD
- **Zero Signature Divergence**: Bundled the Build 86 release signing keystore (`cashbook.keystore`) directly into the project repository.
- **CI/CD Matching Fingerprint**: GitHub Actions builds on Ubuntu now sign using the exact same keystore with SHA-1 `01:D1:FE:DE:79:81:2C:DA:86:24:16:40:77:41:FD:9C:8F:D3:7E:A8`, ensuring in-app updates and downloaded GitHub release APKs never fail Google Play Services identity verification.

### 3. 📲 Native Direct Android Package Installer
- **Native FileProvider & MethodChannel**: 1-tap in-place APK installer without browser redirects.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `dart analyze`.
