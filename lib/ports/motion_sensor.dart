abstract interface class MotionSensor {
  Stream<double> get tiltRadians;
  Stream<void> get shakes;
}
