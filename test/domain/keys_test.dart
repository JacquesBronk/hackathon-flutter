import 'package:cash_me_outside/domain/keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('address is unpadded base64url of 32-byte pubkey; deterministic from seed',
      () async {
    final k1 = await WalletKeys.fromSeed(List.filled(32, 7));
    final k2 = await WalletKeys.fromSeed(List.filled(32, 7));
    expect(k1.address, k2.address);
    expect(k1.address.contains('='), isFalse);
    expect(b64uDecode(k1.address).length, 32);
  });

  test('sign/verify round trip; wrong key fails', () async {
    final k1 = await WalletKeys.fromSeed(List.filled(32, 1));
    final k2 = await WalletKeys.fromSeed(List.filled(32, 2));
    final msg = [1, 2, 3];
    final sig = await k1.sign(msg);
    expect(
        await verifyTransactionSignature(
            from: k1.address, canonicalBytes: msg, signature: sig),
        isTrue);
    expect(
        await verifyTransactionSignature(
            from: k2.address, canonicalBytes: msg, signature: sig),
        isFalse);
    expect(
        await verifyTransactionSignature(
            from: 'not-an-address', canonicalBytes: msg, signature: sig),
        isFalse);
  });

  test('truncateAddr', () {
    expect(truncateAddr('abcdefghijklmnop'), 'abcdef…mnop');
    expect(truncateAddr('short'), 'short');
  });
}
