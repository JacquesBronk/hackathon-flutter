import 'dart:math' as math;
import 'package:cash_me_outside/adapters/compass_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('headingDegreesToRadians', () {
    test('0 degrees is 0 radians (north)', () {
      expect(headingDegreesToRadians(0), 0);
    });

    test('180 degrees is pi radians', () {
      expect(headingDegreesToRadians(180), closeTo(math.pi, 1e-9));
    });

    test('360 degrees is a full turn (2*pi radians)', () {
      expect(headingDegreesToRadians(360), closeTo(2 * math.pi, 1e-9));
    });
  });
}
