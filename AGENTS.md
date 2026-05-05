# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app for Android-to-Android Wi-Fi Direct voice intercom.

- `lib/main.dart`: app entry point, discovery UI, connection state handling, and intercom controls.
- `lib/core/p2p_transceiver.dart`: interface for P2P audio transport.
- `lib/core/host_transceiver.dart` and `lib/core/client_transceiver.dart`: role-specific Wi-Fi Direct and UDP implementations.
- `lib/core/voice_manager.dart`: microphone capture, PCM playback, audio level reporting.
- `android/`: Android configuration, permissions, Gradle files, and launcher resources.
- `test/`: Flutter widget tests. The current default counter test should be replaced with app-specific tests.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies.
- `flutter analyze`: run static analysis using `flutter_lints`.
- `dart format lib test`: format Dart source and tests.
- `flutter test`: run automated Flutter tests.
- `flutter run`: run the app on a connected Android device.
- `flutter build apk`: produce an Android APK.

Wi-Fi Direct behavior requires two physical Android devices; emulators are not suitable for full manual testing.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation. Follow `flutter_lints` unless there is a documented reason to suppress a rule. Keep ownership clear: UI state belongs in `main.dart`, transport code in `lib/core/*_transceiver.dart`, and audio capture/playback in `voice_manager.dart`.

Use `PascalCase` for classes, `camelCase` for methods and variables, and leading underscores for private members. Keep filenames lowercase with underscores, for example `host_transceiver.dart`.

## Testing Guidelines

Use `flutter_test` for widget and unit tests. Name test files with the `_test.dart` suffix and keep them under `test/`. Add focused tests for non-platform logic such as audio level calculations, state transitions, and UI rendering. Verify Wi-Fi Direct flows manually on two devices and document them in PR notes.

Run `flutter analyze` and `flutter test` before submitting changes.

## Commit & Pull Request Guidelines

This checkout has no Git history available, so no existing commit convention can be inferred. Use short, imperative commit subjects such as `Fix client UDP setup` or `Add voice level meter test`.

Pull requests should include a concise summary, test results, target device/Android version when relevant, and screenshots or short recordings for UI changes. For connectivity or audio changes, include manual test steps and observed behavior on both devices.

## Android Permissions & Runtime Notes

Keep Android permission changes in `android/app/src/main/AndroidManifest.xml` aligned with runtime permission requests in `lib/main.dart`. Audio requires `RECORD_AUDIO`; Wi-Fi Direct discovery requires location services and, on newer Android versions, nearby Wi-Fi device permission.
