# sincerelysea

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Recent Fixes

- Fixed Android runtime crash by correcting `MainActivity` package to `com.sincerelysea`.
- Declared the `com.google.gms.google-services` Gradle plugin in `android/settings.gradle.kts` so the app-level plugin can be resolved.

## How to run (device attached)

1. Restart ADB and confirm device:
```powershell
adb kill-server
adb start-server
flutter devices
```
2. Run the app and watch logs (if the Flutter tool reports "The log reader stopped unexpectedly", open a second terminal and stream `logcat`):
```powershell
flutter run -d <device-id>
adb -s <device-id> logcat
```
3. If attachment fails, install and attach manually:
```powershell
flutter build apk
adb -s <device-id> install -r build\\app\\outputs\\flutter-apk\\app-debug.apk
adb -s <device-id> shell am start -n com.sincerelysea/.MainActivity
flutter attach --device-id <device-id>
```

If you want, I can open a PR with these notes or create a small GitHub Action to run `flutter analyze` on push.
