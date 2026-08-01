import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../ports/motion_sensor.dart';

const _gravity = 9.80665;
const _shakeThresholdG = 2.2;
const _shakeDebounce = Duration(milliseconds: 500);

/// Pitch of the device relative to flat/screen-up, derived from the
/// gravity-inclusive accelerometer vector: 0 rad flat, pi/2 rad held
/// vertical. Matches the pour tilt domain in the spec (0.35..1.55 rad).
double tiltRadiansFromAccel(double x, double y, double z) {
  final magnitude = math.sqrt(x * x + y * y + z * z);
  if (magnitude == 0) return 0;
  final cosTilt = (z / magnitude).clamp(-1.0, 1.0);
  return math.acos(cosTilt);
}

/// Debounced shake detection over raw accelerometer samples: magnitude
/// > 2.2g, 500ms debounce (Global Constraints, spec §3).
class ShakeDetector {
  ShakeDetector({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastShake;

  /// Returns true if this sample should fire a shake event.
  bool addSample(double x, double y, double z) {
    final magnitudeInG = math.sqrt(x * x + y * y + z * z) / _gravity;
    if (magnitudeInG <= _shakeThresholdG) return false;
    final now = _now();
    if (_lastShake != null && now.difference(_lastShake!) < _shakeDebounce) {
      return false;
    }
    _lastShake = now;
    return true;
  }
}

class MotionSensorAdapter implements MotionSensor {
  MotionSensorAdapter({ShakeDetector? shakeDetector})
    : _shakeDetector = shakeDetector ?? ShakeDetector();

  final ShakeDetector _shakeDetector;

  Stream<AccelerometerEvent> get _accel =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);

  @override
  Stream<double> get tiltRadians =>
      _accel.map((e) => tiltRadiansFromAccel(e.x, e.y, e.z));

  @override
  Stream<void> get shakes =>
      _accel.where((e) => _shakeDetector.addSample(e.x, e.y, e.z)).map((_) {});
}
