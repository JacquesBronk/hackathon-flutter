import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/keys.dart';
import '../ports/key_vault.dart';

class SecureKeyVault implements KeyVault {
  static const _storage = FlutterSecureStorage();
  static const _key = 'wallet.seed';

  @override
  Future<Uint8List?> loadSeed() async {
    final v = await _storage.read(key: _key);
    return v == null ? null : b64uDecode(v);
  }

  @override
  Future<void> storeSeed(Uint8List seed32) =>
      _storage.write(key: _key, value: b64u(seed32));
}
