import 'dart:typed_data';

abstract interface class KeyVault {
  Future<void> storeSeed(Uint8List seed32);
  Future<Uint8List?> loadSeed();
}
