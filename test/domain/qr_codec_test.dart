import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receive-request round trip, with and without amount', () {
    for (final amount in [null, 250]) {
      final rr = ReceiveRequest(addr: 'someaddr', name: 'Thabo', amount: amount);
      final decoded = decodeQr(encodeReceiveRequest(rr)) as ReceiveRequest;
      expect(decoded.addr, 'someaddr');
      expect(decoded.name, 'Thabo');
      expect(decoded.amount, amount);
    }
  });

  test('signed transaction round trips byte-identically', () async {
    final k = await WalletKeys.fromSeed(List.filled(32, 3));
    final tx = await buildSigned(keys: k, to: k.address, amount: 500,
        type: txTypeMint, lamportTs: 1);
    final decoded =
        (decodeQr(encodeTransaction(tx)) as SignedTransactionPayload)
            .transaction;
    expect(decoded.toJson(), tx.toJson());
  });

  test('malformed and unknown inputs throw QrDecodeException, never crash', () {
    for (final bad in [
      'hello', 'cmo:', 'cmo:zz1:aaaa', 'cmo:rr2:aaaa', 'cmo:rr1:%%%',
      'cmo:tx1:aGVsbG8', // valid b64u, not json
      'cmo:rr1:e30', // {} — missing fields
    ]) {
      expect(() => decodeQr(bad), throwsA(isA<QrDecodeException>()),
          reason: bad);
    }
  });
}
