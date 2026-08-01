import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

final _ed25519 = Ed25519();

String b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64uDecode(String s) {
  final pad = (4 - s.length % 4) % 4;
  return base64Url.decode('$s${'=' * pad}');
}

String truncateAddr(String a) =>
    a.length <= 12 ? a : '${a.substring(0, 6)}…${a.substring(a.length - 4)}';

/// Wallet identity. address = b64u(raw 32-byte Ed25519 public key).
class WalletKeys {
  WalletKeys._(this._keyPair, this.address);
  final SimpleKeyPair _keyPair;
  final String address;

  static Future<WalletKeys> generate() async =>
      _from(await _ed25519.newKeyPair());

  static Future<WalletKeys> fromSeed(List<int> seed32) async =>
      _from(await _ed25519.newKeyPairFromSeed(seed32));

  static Future<WalletKeys> _from(SimpleKeyPair kp) async {
    final pub = await kp.extractPublicKey();
    return WalletKeys._(kp, b64u(pub.bytes));
  }

  Future<Uint8List> seed() async =>
      Uint8List.fromList(await _keyPair.extractPrivateKeyBytes());

  Future<String> sign(List<int> message) async {
    final sig = await _ed25519.sign(message, keyPair: _keyPair);
    return b64u(sig.bytes);
  }
}

/// The signature MUST verify against the key decoded from `from` — anything
/// else is forgery (spec §2.1).
Future<bool> verifyTransactionSignature(
    {required String from,
    required List<int> canonicalBytes,
    required String signature}) async {
  try {
    final pubBytes = b64uDecode(from);
    final sigBytes = b64uDecode(signature);
    if (pubBytes.length != 32 || sigBytes.length != 64) return false;
    return await _ed25519.verify(
      canonicalBytes,
      signature: Signature(sigBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519)),
    );
  } catch (_) {
    return false;
  }
}
