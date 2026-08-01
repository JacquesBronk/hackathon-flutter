import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import '../ports/compass_port.dart';

double headingDegreesToRadians(double degrees) => degrees * math.pi / 180;

/// Thin wrapper over flutter_compass. Readings with no heading (no sensor on
/// device) are dropped rather than surfaced — callers see a clean stream of
/// radians or nothing.
class CompassAdapter implements CompassPort {
  @override
  Stream<double> get headingRadians =>
      (FlutterCompass.events ?? const Stream.empty())
          .map((e) => e.heading)
          .where((h) => h != null)
          .map((h) => headingDegreesToRadians(h!));
}
