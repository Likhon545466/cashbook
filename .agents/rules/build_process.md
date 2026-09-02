# Release Build Guidelines

Whenever creating a release build or APK for this project:

1. **Use `build.bat` / Version System**:
   - Always respect the Permanent Version System defined in [`build.bat`](file:///d:/AppDev/cashbook/build.bat).
   - The version source of truth is [`.cashbook_version`](file:///d:/AppDev/cashbook/.cashbook_version) (do not edit `pubspec.yaml` for version bumps).
   - Either run `build.bat` directly or pass `--build-name` and `--build-number` matching the incremented `.cashbook_version` state.
   - Name output APKs formatted as: `CashBook-v<VERSION_NAME>-build<BUILD_NUMBER>.apk`.

2. **GitHub Push Confirmation**:
   - **Never** push changes to the remote GitHub repository without explicit user confirmation first.
