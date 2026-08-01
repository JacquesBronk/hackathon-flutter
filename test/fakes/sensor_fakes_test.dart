import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeMotionSensor emits injected tilt and shake events', () async {
    final sensor = FakeMotionSensor();
    final tilts = <double>[];
    final shakes = <void>[];
    final sub1 = sensor.tiltRadians.listen(tilts.add);
    final sub2 = sensor.shakes.listen(shakes.add);

    sensor.emitTilt(0.5);
    sensor.emitShake();
    await pumpEventQueue();

    expect(tilts, [0.5]);
    expect(shakes, hasLength(1));
    await sub1.cancel();
    await sub2.cancel();
  });

  test('FakeHaptics counts ticks', () async {
    final haptics = FakeHaptics();
    expect(haptics.tickCount, 0);
    await haptics.tick();
    await haptics.tick();
    expect(haptics.tickCount, 2);
  });

  test('FakeCompassPort emits injected headings', () async {
    final compass = FakeCompassPort();
    final headings = <double>[];
    final sub = compass.headingRadians.listen(headings.add);

    compass.emitHeadingRadians(1.5);
    await pumpEventQueue();

    expect(headings, [1.5]);
    await sub.cancel();
  });
}
