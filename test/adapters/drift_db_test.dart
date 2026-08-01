import 'package:cash_me_outside/adapters/drift_db.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriftLedgerStore round trips transactions and lamport', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftLedgerStore(db);
    expect(await store.loadAll(), isEmpty);
    expect(await store.loadLamport(), 0);
    final k = await WalletKeys.fromSeed(List.filled(32, 4));
    final tx = await buildSigned(
      keys: k,
      to: k.address,
      amount: 500,
      type: txTypeMint,
      lamportTs: 1,
    );
    await store.save(tx);
    await store.save(tx); // idempotent upsert, no throw
    await store.saveLamport(7);
    final loaded = await store.loadAll();
    expect(loaded.single.toJson(), tx.toJson());
    expect(await store.loadLamport(), 7);
  });

  test('DriftPeerDirectory round trips and upserts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = DriftPeerDirectory(db);
    await dir.record('a1', 'Anna');
    await dir.record('a1', 'Anna B');
    expect(await dir.nameFor('a1'), 'Anna B');
    expect(await dir.nameFor('zz'), isNull);
  });
}
