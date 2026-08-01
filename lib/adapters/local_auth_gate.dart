import 'package:local_auth/local_auth.dart';
import '../ports/biometric_gate.dart';

class LocalAuthGate implements BiometricGate {
  final _auth = LocalAuthentication();

  @override
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // spec §4.1: device-credential fallback, never biometricOnly. local_auth
        // 3.x flattened AuthenticationOptions into direct named params on
        // authenticate() — there is no `options:` argument anymore.
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
