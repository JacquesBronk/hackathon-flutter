import 'package:cash_me_outside/domain/canonical.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

late WalletKeys alice, bob;

Future<Transaction> mint(WalletKeys k, {String? id, int amount = 500}) =>
    buildSigned(
      keys: k,
      to: k.address,
      amount: amount,
      type: txTypeMint,
      lamportTs: 1,
      id: id,
    );

Future<Transaction> pay(
  WalletKeys from,
  WalletKeys to,
  int amount, {
  int lamport = 2,
  String? memo,
}) => buildSigned(
  keys: from,
  to: to.address,
  amount: amount,
  memo: memo,
  type: txTypeTransfer,
  lamportTs: lamport,
);

void main() {
  setUpAll(() async {
    alice = await WalletKeys.fromSeed(List.filled(32, 1));
    bob = await WalletKeys.fromSeed(List.filled(32, 2));
  });

  test('mint + transfer replay; negative balances allowed', () async {
    final l = Ledger();
    await l.ingest(await mint(alice));
    await l.ingest(await pay(alice, bob, 700));
    expect(l.balances()[alice.address], -200);
    expect(l.balances()[bob.address], 700);
  });

  test('convergence: permuted merge orders yield identical state', () async {
    final txs = [
      await mint(alice),
      await mint(bob),
      await pay(alice, bob, 100),
      await pay(bob, alice, 30, lamport: 3),
    ];
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

  test('id collision: both distinct-bytes transactions survive', () async {
    final a = await mint(alice, id: '01890000-0000-7000-8000-00000000aaaa');
    // Same id as `a`, different content, validly signed:
    final collider = await buildSigned(
      keys: alice,
      to: bob.address,
      amount: 9,
      type: txTypeTransfer,
      lamportTs: 2,
      id: a.id,
    );
    final l = Ledger();
    expect((await l.ingest(a)).status, IngestStatus.added);
    expect((await l.ingest(collider)).status, IngestStatus.added);
    expect(l.ordered.length, 2);
  });

  test('forgery rejected: tampered amount, wrong signer', () async {
    final t = await pay(alice, bob, 100);
    final tampered = Transaction(
      id: t.id,
      type: t.type,
      from: t.from,
      to: t.to,
      amount: 9999,
      memo: t.memo,
      lamportTs: t.lamportTs,
      signature: t.signature,
    );
    final wrongSigner =
        await buildSigned(
          keys: bob,
          to: bob.address,
          amount: 5,
          type: txTypeTransfer,
          lamportTs: 2,
        ).then(
          (x) => Transaction(
            id: x.id,
            type: x.type,
            from: alice.address,
            to: x.to,
            amount: x.amount,
            memo: x.memo,
            lamportTs: x.lamportTs,
            signature: x.signature,
          ),
        );
    final l = Ledger();
    expect((await l.ingest(tampered)).status, IngestStatus.rejected);
    expect((await l.ingest(wrongSigner)).status, IngestStatus.rejected);
  });

  test('amount range: 0, negative, > 2^53-1 rejected', () async {
    final l = Ledger();
    for (final bad in [0, -5, maxAmount + 1]) {
      final t = await buildSigned(
        keys: alice,
        to: bob.address,
        amount: bad,
        type: txTypeTransfer,
        lamportTs: 2,
      );
      expect(
        (await l.ingest(t)).status,
        IngestStatus.rejected,
        reason: 'amount $bad must be rejected',
      );
    }
  });

  test('mint rules: wrong amount, wrong recipient rejected; duplicate mint '
      'counted once deterministically under any merge order', () async {
    final l = Ledger();
    expect(
      (await l.ingest(await mint(alice, amount: 501))).status,
      IngestStatus.rejected,
    );
    final notSelf = await buildSigned(
      keys: alice,
      to: bob.address,
      amount: 500,
      type: txTypeMint,
      lamportTs: 1,
    );
    expect((await l.ingest(notSelf)).status, IngestStatus.rejected);

    final m1 = await mint(alice, id: '01890000-0000-7000-8000-000000000001');
    final m2 = await mint(alice, id: '01890000-0000-7000-8000-000000000002');
    final la = Ledger();
    final lb = Ledger();
    await la.ingest(m1);
    await la.ingest(m2);
    await lb.ingest(m2);
    await lb.ingest(m1);
    expect(la.balances()[alice.address], 500);
    expect(lb.balances()[alice.address], 500);
    // Observe the (lamportTs, id) tie-break itself, not just the 500:
    // identical total order under both merge orders, smaller id first.
    expect(
      la.ordered.map((t) => t.id).toList(),
      lb.ordered.map((t) => t.id).toList(),
    );
    expect(la.ordered.first.id, m1.id);
  });

  test('signed unicode memo survives the full sign→ingest path', () async {
    final l = Ledger();
    final t = await pay(alice, bob, 10, memo: 'pizza 🍕 ✨');
    expect((await l.ingest(t)).status, IngestStatus.added);
  });

  test(
    'duplicate ingest is idempotent; unknown type retained but ignored',
    () async {
      final l = Ledger();
      final t = await mint(alice);
      expect((await l.ingest(t)).status, IngestStatus.added);
      expect((await l.ingest(t)).status, IngestStatus.duplicate);
      final burn = await buildSigned(
        keys: alice,
        to: bob.address,
        amount: 5,
        type: 'burn',
        lamportTs: 4,
      );
      expect((await l.ingest(burn)).status, IngestStatus.added);
      expect(l.balances()[bob.address], isNot(5));
      expect(l.ordered.any((x) => x.type == 'burn'), isTrue);
    },
  );

  test('lamport clock', () {
    final c = LamportClock();
    expect(c.next(0), 1);
    expect(c.next(10), 11);
    expect(c.next(3), 12);
    expect(c.value, 12);
  });
}
