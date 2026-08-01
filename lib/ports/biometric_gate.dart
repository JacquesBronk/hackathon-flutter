abstract interface class BiometricGate {
  Future<bool> get isAvailable;
  Future<bool> authenticate(String reason);
}
