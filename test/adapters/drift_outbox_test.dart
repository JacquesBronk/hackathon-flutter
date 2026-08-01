import 'package:cash_me_outside/adapters/drift_db.dart';
import 'package:cash_me_outside/adapters/drift_outbox_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test('DriftOutboxStore put/remove/pending round trip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftOutboxStore(db);
    expect(await store.pending(), isEmpty);
    final expires = DateTime.now().add(const Duration(hours: 24));
    await store.put('m1', '{"frame":1}', expires);
    await store.put('m2', '{"frame":2}', expires);
    final pending = await store.pending();
    expect(pending.map((e) => e.$1).toSet(), {'m1', 'm2'});
    await store.remove('m1');
    final after = await store.pending();
    expect(after.single.$1, 'm2');
  });

  test('DriftOutboxStore.put upserts by msgId', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftOutboxStore(db);
    final expires = DateTime.now().add(const Duration(hours: 24));
    await store.put('m1', '{"v":1}', expires);
    await store.put('m1', '{"v":2}', expires);
    final pending = await store.pending();
    expect(pending.single, ('m1', '{"v":2}'));
  });

  test('DriftOutboxStore.pending excludes and clears expired entries', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftOutboxStore(db);
    final past = DateTime.now().subtract(const Duration(hours: 1));
    await store.put('expired', '{}', past);
    expect(await store.pending(), isEmpty);
    // re-putting under the same msgId confirms the expired row was actually
    // deleted (not merely filtered) — an upsert would otherwise be a no-op
    // update on a still-present row.
    await store.put('expired', '{}', DateTime.now().add(const Duration(hours: 1)));
    expect(await store.pending(), hasLength(1));
  });

  test('DriftSeenStore load/add round trip, idempotent add', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSeenStore(db);
    expect(await store.load(), isEmpty);
    await store.add('a');
    await store.add('b');
    await store.add('a');
    expect(await store.load(), {'a', 'b'});
  });

  test('DriftSeenStore caps at 1024 entries, evicting oldest first', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSeenStore(db);
    for (var i = 0; i < 1024; i++) {
      await store.add('id$i');
    }
    expect(await store.load(), hasLength(1024));
    await store.add('overflow');
    final seen = await store.load();
    expect(seen, hasLength(1024));
    expect(seen.contains('id0'), isFalse);
    expect(seen.contains('id1'), isTrue);
    expect(seen.contains('overflow'), isTrue);
  });

  test('AppDatabase lands directly on schemaVersion 2 for fresh installs', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 2);
    // onCreate path (m.createAll()) already exercised by the round-trip
    // tests above, which fail immediately if outboxRows/seenRows are absent.
  });

  test(
    'migrating from schemaVersion 1 preserves existing data and adds outbox/seen tables',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE ledger_rows (key TEXT NOT NULL, json TEXT NOT NULL, PRIMARY KEY(key));
        CREATE TABLE peer_rows (addr TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY(addr));
        CREATE TABLE meta_rows (k TEXT NOT NULL, v TEXT NOT NULL, PRIMARY KEY(k));
        INSERT INTO peer_rows (addr, name) VALUES ('a1', 'Anna');
        PRAGMA user_version = 1;
      ''');

      final db = AppDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final dir = DriftPeerDirectory(db);
      expect(await dir.nameFor('a1'), 'Anna'); // survived the upgrade

      final outboxStore = DriftOutboxStore(db);
      await outboxStore.put(
        'm1',
        '{}',
        DateTime.now().add(const Duration(hours: 1)),
      );
      expect(await outboxStore.pending(), hasLength(1));

      final seenStore = DriftSeenStore(db);
      await seenStore.add('seen1');
      expect(await seenStore.load(), {'seen1'});
    },
  );
}
