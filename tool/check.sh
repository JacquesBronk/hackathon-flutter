#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart run build_runner build --delete-conflicting-outputs
# Format-check only human-written, tracked Dart files. Generated *.g.dart is
# emitted by drift_dev's bundled formatter and must never be able to fail the
# gate (SDK-formatter drift would otherwise livelock it permanently).
git ls-files '*.dart' | grep -v '\.g\.dart$' | xargs -r dart format --set-exit-if-changed
flutter analyze
flutter test
