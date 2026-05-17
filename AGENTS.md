# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app for Android-to-Android Wi-Fi Direct voice intercom.

- `lib/main.dart`: app entry point, Wi-Fi Direct discovery UI, peer list, connection state handling, connected-device display, debug log display, audio level meters, intercom controls, disconnect handling, and Android sleep-lock method channel calls.
- `lib/core/p2p_transceiver.dart`: shared interface for P2P audio transport implementations.
- `lib/core/host_transceiver.dart`: Group Owner side transport. It binds UDP port `8888`, records the sender IP from received packets, and sends audio frames back to that peer.
- `lib/core/client_transceiver.dart`: Client side transport. It uses the Group Owner address from Wi-Fi P2P info, binds UDP port `8888`, and sends/receives audio frames.
- `lib/core/voice_manager.dart`: microphone capture, PCM playback, audio stream wiring, and send/receive audio level reporting.
- `android/`: Android configuration, permissions, Gradle files, launcher resources, and native foreground service code for wake/Wi-Fi locks.
- `test/`: Flutter widget tests. The current default counter test should be replaced with app-specific tests.

## Current App Capabilities

The current implementation provides a debug-oriented P2P intercom flow for two physical Android devices:

- Initializes and registers `flutter_p2p_connection`.
- Scans for Wi-Fi Direct peers with the `Scan` action.
- Creates a Wi-Fi Direct group with `Create Group`.
- Displays discovered peers and sends a connection request when a peer is tapped.
- Monitors Wi-Fi P2P connection info and automatically selects Host or Client transport.
- Shows connected peer name, address, and role when available.
- Starts and stops an intercom session after connection.
- Captures microphone audio as PCM 16-bit, 16 kHz, mono via `record`.
- Sends and receives raw PCM audio over UDP port `8888`.
- Plays received PCM with `flutter_pcm_sound`.
- Displays simple MIC sent-level and SPEAKER received-level meters.
- Maintains a small in-app debug log.
- Starts an Android foreground service while intercom is running to hold a partial wake lock and high-performance Wi-Fi lock.
- Disconnects by stopping audio, releasing locks, closing UDP sockets, and removing the Wi-Fi Direct group.

## Known Limitations

- Full behavior requires two physical Android devices; emulators are not suitable for Wi-Fi Direct testing.
- Audio transport is raw UDP PCM. There is no jitter buffer, packet loss handling, echo cancellation, codec, encryption, or latency compensation.
- On the Host side, `_peerAddress` is learned from the first received UDP packet, so the Host cannot send audio to the Client until at least one packet has arrived from the Client.
- `VoiceManager.init()` only prints when microphone permission is missing; it does not currently surface an error state back to the UI.
- The default `test/widget_test.dart` still tests the Flutter counter template and does not match this app.

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

The Android native side includes `MainActivity.kt` and `IntercomForegroundService.kt`. The Flutter method channel `wifi_transceiver/power` starts and stops the foreground service with `acquireSleepLocks` and `releaseSleepLocks`. The service keeps microphone/Wi-Fi operation active using `WAKE_LOCK`, a high-performance `WifiLock`, and foreground service permissions.
