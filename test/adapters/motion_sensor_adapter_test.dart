import 'dart:math' as math;
import 'package:cash_me_outside/adapters/motion_sensor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tiltRadiansFromAccel', () {
    test('flat, screen up (gravity on z) is zero tilt', () {
      expect(tiltRadiansFromAccel(0, 0, 9.80665), closeTo(0, 1e-9));
    });

    test('held vertical (gravity on y) is pi/2 tilt', () {
      expect(tiltRadiansFromAccel(0, 9.80665, 0), closeTo(math.pi / 2, 1e-9));
    });

    test('upside down flat (gravity opposes z) is pi tilt', () {
      expect(tiltRadiansFromAccel(0, 0, -9.80665), closeTo(math.pi, 1e-9));
    });

    test('is invariant to the magnitude of the vector, only its direction', () {
      final a = tiltRadiansFromAccel(0, 4.9, 4.9);
      final b = tiltRadiansFromAccel(0, 9.8, 9.8);
      expect(a, closeTo(b, 1e-9));
    });

    test('zero vector does not throw or produce NaN', () {
      expect(tiltRadiansFromAccel(0, 0, 0), 0);
    });
  });

  group('ShakeDetector', () {
    test('fires on a sample above the 2.2g threshold', () {
      final detector = ShakeDetector(now: () => DateTime(2026));
      expect(detector.addSample(0, 0, 25), isTrue); // ~2.55g
    });

    test('does not fire below the threshold', () {
      final detector = ShakeDetector(now: () => DateTime(2026));
      expect(detector.addSample(0, 0, 9.8), isFalse); // ~1g, resting
    });

    test('debounces repeated shakes within 500ms', () {
      var now = DateTime(2026);
      final detector = ShakeDetector(now: () => now);

      expect(detector.addSample(0, 0, 25), isTrue);
      now = now.add(const Duration(milliseconds: 200));
      expect(detector.addSample(0, 0, 25), isFalse);
      now = now.add(const Duration(milliseconds: 200));
      expect(detector.addSample(0, 0, 25), isFalse);
    });

    test('fires again once the debounce window has elapsed', () {
      var now = DateTime(2026);
      final detector = ShakeDetector(now: () => now);

      expect(detector.addSample(0, 0, 25), isTrue);
      now = now.add(const Duration(milliseconds: 500));
      expect(detector.addSample(0, 0, 25), isTrue);
    });
  });
}
