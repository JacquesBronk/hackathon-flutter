import 'dart:async';
import '../ports/haptics.dart';
import '../ports/motion_sensor.dart';

/// Programmable fake motion sensor — tests drive tilt/shake events directly,
/// no accelerometer math involved.
class FakeMotionSensor implements MotionSensor {
  final _tilt = StreamController<double>.broadcast();
  final _shakes = StreamController<void>.broadcast();

  @override
  Stream<double> get tiltRadians => _tilt.stream;
  @override
  Stream<void> get shakes => _shakes.stream;

  void emitTilt(double radians) => _tilt.add(radians);
  void emitShake() => _shakes.add(null);
}

class FakeHaptics implements Haptics {
  int tickCount = 0;
  @override
  Future<void> tick() async => tickCount++;
}
