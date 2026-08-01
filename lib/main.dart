import 'package:flutter/material.dart';
import 'app.dart';
import 'providers.dart';

void main() {
  const useFakes = bool.fromEnvironment('FAKE_HARDWARE');
  runApp(
    CashMeOutsideApp(
      overrides: useFakes ? fakeHardwareOverrides() : realHardwareOverrides(),
      enableMeshRealWiring: !useFakes,
    ),
  );
}
