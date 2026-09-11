# 🚀 CashBook Release Notes - v1.8.3 (Build 87)

**Release Date:** September 11, 2026  
**Build Target:** Android (Release APK `CashBook-v1.8.3-build87.apk`)

---

## 🌟 What's New in v1.8.3

### 1. ⚡ Direct Update Link & Tag Matching Optimization
- **Sanitized URL Tag Encoding**: URL-encoded tags (`%2B`) with base version deduplication to guarantee 100% accurate download target matching.
- **Failover & Recovery State**: Added 1-tap **"Retry Download"** and clear recovery cues when an APK asset is being attached.

### 2. 📥 In-App Download Progress & Direct Native Installer
- **Live Streaming Progress Bar**: Live streaming binary download with speed counter (`MB/s`), total megabytes, and cancelability.
- **Direct Package Installer Launch**: Prompts native package installer on download completion.

### 3. ⚙️ Configurable Auto-Update Check Frequency
- Choose between `Every Startup`, `Once Daily`, `Once a Week`, or `Manual Only` with persistent SQLite storage.

---

## 🌟 Previous Features (v1.8.0 - v1.8.2)

- **Two-Tier Resilient Check**: GitHub REST API + Atom feed & raw repo rate-limit bypass.
- **Glassmorphic Popup Dialog**: Beautiful non-blocking update notification on app startup.
- **Interactive Radar Scanner**: Dedicated manual update check in Settings with pulse wave animations.

---

## 🛠 Quality & Performance
- 🧪 **100% Test Coverage**: All 89 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
