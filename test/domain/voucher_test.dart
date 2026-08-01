import 'dart:typed_data';

import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/domain/voucher.dart';
import 'package:flutter_test/flutter_test.dart';

late WalletKeys alice, bob, carol;

Future<Transaction> mint(WalletKeys k, {int lamport = 1}) => buildSigned(
  keys: k,
  to: k.address,
  amount: 500,
  type: txTypeMint,
  lamportTs: lamport,
);

void main() {
  setUpAll(() async {
    alice = await WalletKeys.fromSeed(List.filled(32, 1));
    bob = await WalletKeys.fromSeed(List.filled(32, 2));
    carol = await WalletKeys.fromSeed(List.filled(32, 3));
  });

  test('mintVoucher round trips through the codec', () async {
    final (uri, seed) = await mintVoucher(
      owner: alice,
      amount: 50,
      lamportTs: 2,
    );
    final decoded = decodeQr(uri) as VoucherPayload;
    expect(decoded.tx.from, alice.address);
    expect(decoded.tx.amount, 50);
    expect(decoded.seed, seed);
    final throwaway = await WalletKeys.fromSeed(seed);
    expect(decoded.tx.to, throwaway.address);
  });

  test('full mint→claim ledger test: owner debited once, claimant credited via '
      'sweep, replay-stable under merge permutations', () async {
    final mintTx = await mint(alice);
    final (voucherUri, _) = await mintVoucher(
      owner: alice,
      amount: 200,
      lamportTs: 2,
    );
    final voucher = decodeQr(voucherUri) as VoucherPayload;

    final ledger = Ledger();
    await ledger.ingest(mintTx);
    final claimed = await claimVoucher(
      ledger: ledger,
      voucher: voucher,
      claimant: bob.address,
      lamportTs: 3,
    );
    expect(claimed, isNotNull);
    final (voucherTx, sweepTx) = claimed!;
    expect(voucherTx.toJson(), voucher.tx.toJson());
    expect(sweepTx.to, bob.address);
    expect(sweepTx.amount, 200);

    final throwaway = await WalletKeys.fromSeed(voucher.seed);
    expect(sweepTx.from, throwaway.address);
    expect(ledger.balances()[alice.address], 300); // 500 minted - 200
    expect(ledger.balances()[bob.address], 200);
    expect(ledger.balances()[throwaway.address], 0); // +200 then -200

    // Replay-stable: any merge order of the three resulting txs converges.
    final txs = [mintTx, voucherTx, sweepTx];
    final l1 = Ledger();
    final l2 = Ledger();
    for (final t in txs) {
      await l1.ingest(t);
    }
    for (final t in txs.reversed) {
      await l2.ingest(t);
    }
    expect(l1.balances(), l2.balances());
    expect(l1.ordered.map((t) => t.id), l2.ordered.map((t) => t.id));
  });

  test(
    'double-claim is a sanctioned feature: two claimants both credit',
    () async {
      final mintTx = await mint(alice);
      final (voucherUri, seed) = await mintVoucher(
        owner: alice,
        amount: 200,
        lamportTs: 2,
      );
      final voucher = decodeQr(voucherUri) as VoucherPayload;

      final ledger = Ledger();
      await ledger.ingest(mintTx);

      final firstClaim = await claimVoucher(
        ledger: ledger,
        voucher: voucher,
        claimant: bob.address,
        lamportTs: 3,
      );
      final secondClaim = await claimVoucher(
        ledger: ledger,
        voucher: voucher,
        claimant: carol.address,
        lamportTs: 4,
      );
      expect(firstClaim, isNotNull);
      expect(secondClaim, isNotNull);
      // Same voucher tx both times, but distinct sweeps.
      expect(firstClaim!.$1.id, secondClaim!.$1.id);
      expect(firstClaim.$2.id, isNot(secondClaim.$2.id));

      final throwaway = await WalletKeys.fromSeed(seed);
      expect(ledger.balances()[alice.address], 300);
      expect(ledger.balances()[bob.address], 200);
      expect(ledger.balances()[carol.address], 200);
      // Credited once, swept twice — negative balances are allowed by
      // design; the UI never promises exclusivity (spec §4).
      expect(ledger.balances()[throwaway.address], -200);
    },
  );

  test(
    'claimVoucher returns null when the voucher tx fails validation',
    () async {
      final tx = await buildSigned(
        keys: alice,
        to: bob.address,
        amount: 200,
        type: txTypeTransfer,
        lamportTs: 2,
      );
      final tampered = Transaction(
        id: tx.id,
        type: tx.type,
        from: tx.from,
        to: tx.to,
        amount: 9999, // signature no longer matches
        memo: tx.memo,
        lamportTs: tx.lamportTs,
        signature: tx.signature,
      );
      final voucher = VoucherPayload(
        tx: tampered,
        seed: Uint8List.fromList(List.filled(32, 9)),
      );
      final ledger = Ledger();
      final result = await claimVoucher(
        ledger: ledger,
        voucher: voucher,
        claimant: carol.address,
        lamportTs: 3,
      );
      expect(result, isNull);
      expect(ledger.ordered, isEmpty);
    },
  );
}
