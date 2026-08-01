import 'dart:convert';

import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receive-request round trip, with and without amount', () {
    for (final amount in [null, 250]) {
      final rr = ReceiveRequest(
        addr: 'someaddr',
        name: 'Thabo',
        amount: amount,
      );
      final decoded = decodeQr(encodeReceiveRequest(rr)) as ReceiveRequest;
      expect(decoded.addr, 'someaddr');
      expect(decoded.name, 'Thabo');
      expect(decoded.amount, amount);
    }
  });

  test('signed transaction round trips byte-identically', () async {
    final k = await WalletKeys.fromSeed(List.filled(32, 3));
    final tx = await buildSigned(
      keys: k,
      to: k.address,
      amount: 500,
      type: txTypeMint,
      lamportTs: 1,
    );
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
      expect(
        () => decodeQr(bad),
        throwsA(isA<QrDecodeException>()),
        reason: bad,
      );
    }
  });

  test('voucher round trips byte-identically', () async {
    final owner = await WalletKeys.fromSeed(List.filled(32, 4));
    final throwaway = await WalletKeys.fromSeed(List.filled(32, 5));
    final seed = await throwaway.seed();
    final tx = await buildSigned(
      keys: owner,
      to: throwaway.address,
      amount: 50,
      type: txTypeTransfer,
      lamportTs: 2,
    );
    final uri = encodeVoucher(VoucherPayload(tx: tx, seed: seed));
    expect(uri, startsWith('cmo:v1:'));
    final decoded = decodeQr(uri) as VoucherPayload;
    expect(decoded.tx.toJson(), tx.toJson());
    expect(decoded.seed, seed);
  });

  test('malformed vouchers throw QrDecodeException', () async {
    final owner = await WalletKeys.fromSeed(List.filled(32, 4));
    final throwaway = await WalletKeys.fromSeed(List.filled(32, 5));
    final seed = await throwaway.seed();
    final tx = await buildSigned(
      keys: owner,
      to: throwaway.address,
      amount: 50,
      type: txTypeTransfer,
      lamportTs: 2,
    );
    final validTxUri = encodeTransaction(tx);
    final rr = ReceiveRequest(addr: 'someaddr', name: 'Thabo');

    String wrap(Map<String, Object?> json) =>
        'cmo:v1:${b64u(utf8.encode(jsonEncode(json)))}';

    for (final bad in [
      'cmo:v1:%%%', // invalid b64u envelope
      wrap({'seed': b64u(seed)}), // missing tx
      wrap({'tx': validTxUri}), // missing seed
      wrap({'tx': 123, 'seed': b64u(seed)}), // tx not a string
      wrap({'tx': validTxUri, 'seed': 123}), // seed not a string
      wrap({'tx': validTxUri, 'seed': '%%%'}), // seed not valid b64u
      wrap({'tx': validTxUri, 'seed': b64u(List.filled(16, 1))}), // short seed
      wrap({'tx': 'not a cmo uri at all', 'seed': b64u(seed)}),
      wrap({'tx': encodeReceiveRequest(rr), 'seed': b64u(seed)}), // wrong kind
    ]) {
      expect(
        () => decodeQr(bad),
        throwsA(isA<QrDecodeException>()),
        reason: bad,
      );
    }
  });
}
