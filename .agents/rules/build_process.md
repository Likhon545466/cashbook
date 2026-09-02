# Build & Git Policies

## 1. Permanent Version System & Build Script
- Always follow the version sequence in [`.cashbook_version`](file:///d:/AppDev/cashbook/.cashbook_version) (e.g. `1.5.8+62` &rarr; next build is `1.5.9+63`).
- **Never** modify `pubspec.yaml` for version bumps.
- When compiling, use [`build.bat`](file:///d:/AppDev/cashbook/build.bat) or pass `--build-name` and `--build-number` matching `.cashbook_version`.
- **Local Build Retention**: Keep only the **latest 2 builds** locally in `build\app\outputs\flutter-apk\` and `Release\`, automatically pruning older builds.

## 2. Git & Release Workflow
- **Auto-Push Code**: Code changes can be committed and pushed to GitHub automatically.
- **APK Release**: **Never** create or distribute an APK release (or GitHub release asset) without explicit user permission.
