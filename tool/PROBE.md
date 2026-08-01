# Toolchain Probe

Recorded 2026-08-01 as part of Task 1 (Toolchain probe + project foundation).

## `flutter --version`

```
Flutter 3.44.8 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 058e0af2c2 (9 days ago) • 2026-07-23 10:56:21 -0700
Engine • hash 13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939 (revision 0cd610717b) (8 days ago) • 2026-07-23 16:11:34.000Z
Tools • Dart 3.12.2 • DevTools 2.57.0
```

## `flutter doctor -v`

```
[✓] Flutter (Channel stable, 3.44.8, on Debian GNU/Linux 12 (bookworm) 6.12.94+deb13-amd64, locale en_US) [37ms]
    • Flutter version 3.44.8 on channel stable at /opt/flutter
    • Upstream repository https://github.com/flutter/flutter.git
    • Framework revision 058e0af2c2 (9 days ago), 2026-07-23 10:56:21 -0700
    • Engine revision 0cd610717b
    • Dart version 3.12.2
    • DevTools version 2.57.0
    • Feature flags: enable-web, enable-linux-desktop, enable-macos-desktop, enable-windows-desktop, enable-android, enable-ios, cli-animations, enable-native-assets, enable-swift-package-manager, omit-legacy-version-file, enable-lldb-debugging, enable-uiscene-migration

[✗] Android toolchain - develop for Android devices [25ms]
    ✗ Unable to locate Android SDK.
      Install Android Studio from: https://developer.android.com/studio/index.html
      On first launch it will assist you in installing the Android SDK components.
      (or visit https://flutter.dev/to/linux-android-setup for detailed instructions).
      If the Android SDK has been installed to a custom location, please use
      `flutter config --android-sdk` to update to that location.

[✗] Chrome - develop for the web (Cannot find Chrome executable at google-chrome) [12ms]
    ! Cannot find Chrome. Try setting CHROME_EXECUTABLE to a Chrome executable.

[✗] Linux toolchain - develop for Linux desktop [30ms]
    ✗ clang++ is required for Linux development.
    ✗ CMake is required for Linux development.
    ✗ ninja is required for Linux development.
    ✗ pkg-config is required for Linux development.

[✓] Connected device (1 available) [33ms]
    • Linux (desktop) • linux • linux-x64 • Debian GNU/Linux 12 (bookworm) 6.12.94+deb13-amd64

[✓] Network resources [617ms]
    • All expected network resources are available.

! Doctor found issues in 3 categories.
```

## `java -version`

```
/bin/bash: line 1: java: command not found
NO JAVA
```

## APK capability probe (throwaway project outside repo)

```
$ cd "$(mktemp -d)" && flutter create probe_apk --org dev.jcqb --platforms android && cd probe_apk && flutter build apk --debug
...
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
EXIT_CODE=1
```

**Verdict: `APK_UNAVAILABLE`.** No Android SDK and no JDK are installed in this
Bureau worker. Per spec §6 / plan Step 1, the APK gates are dropped from this
graph — `flutter build apk --debug` is **not** run as part of `tool/check.sh`
or any task's completion gate. The owner builds and sideloads the APK locally
for the human device pass (spec §6, "Human device pass"). This does not affect
`flutter analyze` / `flutter test` / `dart format`, which all run fully
offline against the Dart SDK bundled with Flutter and bind every task as
normal.

Throwaway probe project was created under a `mktemp -d` directory outside the
repo and deleted after use; it left no trace in this repository.

## Dependency versions (recorded after Step 3 lands `pubspec.lock`)

Flutter 3.44.8 / Dart 3.12.2 (from `flutter --version` above, unchanged after
`pub add`).

Resolved major/full versions from `pubspec.lock`:

| package | resolved version |
|---|---|
| `flutter_riverpod` | 2.6.1 (pinned `^2.6.1` per Global Constraints — do not upgrade to 3.x) |
| `drift` | 2.34.3 |
| `drift_dev` (dev) | 2.34.5 |
| `local_auth` | 3.0.2 |
| `mobile_scanner` | 7.4.0 |
| `flutter_secure_storage` | 10.3.1 |
| `sqlite3` (dev) | 3.5.0 |

### minSdk 24 / compileSdk 36 floor check

Checked each plugin's own `android/build.gradle(.kts)` in the pub cache
(`/tmp/pub-cache/hosted/pub.dev/<pkg>/android/build.gradle*`) rather than
relying on trained knowledge, since these floors move release to release:

- `local_auth_android-2.0.9`: `compileSdk = flutter.compileSdkVersion` (→ 36),
  `minSdk = 24`. Exactly matches our config.
- `mobile_scanner-7.4.0`: `compileSdk = 36`, `minSdk = 23`. Our `minSdk = 24`
  is above its floor — satisfied.
- `flutter_secure_storage-10.3.1`: `compileSdk = 36`, `minSdkVersion = 23`.
  Same — satisfied.

No plugin here demands a `minSdk`/`compileSdk` above what this project sets
(`android/app/build.gradle.kts`: `compileSdk = 36`, `minSdk = 24`). No AGP-pin
escape hatch was needed for these three; revisit this table if T4 adds a
library with a stricter floor.
