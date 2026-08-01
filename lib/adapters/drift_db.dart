import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../domain/canonical.dart';
import '../domain/transaction.dart' as domain;
import '../ports/ledger_store.dart';
import '../ports/peer_directory.dart';

part 'drift_db.g.dart';

class LedgerRows extends Table {
  TextColumn get key => text()(); // sha256 hex of canonical bytes
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class PeerRows extends Table {
  TextColumn get addr => text()();
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {addr};
}

class MetaRows extends Table {
  TextColumn get k => text()();
  TextColumn get v => text()();
  @override
  Set<Column> get primaryKey => {k};
}

@DriftDatabase(tables: [LedgerRows, PeerRows, MetaRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 1;
}

AppDatabase openAppDatabase() => AppDatabase(driftDatabase(name: 'cmo'));

class DriftLedgerStore implements LedgerStore {
  DriftLedgerStore(this._db);
  final AppDatabase _db;

  @override
  Future<List<domain.Transaction>> loadAll() async {
    final rows = await _db.select(_db.ledgerRows).get();
    return rows
        .map(
          (r) => domain.Transaction.fromJson(
            jsonDecode(r.json) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  @override
  Future<void> save(domain.Transaction tx) => _db
      .into(_db.ledgerRows)
      .insertOnConflictUpdate(
        LedgerRowsCompanion.insert(
          key: ledgerKeyOf(tx),
          json: jsonEncode(tx.toJson()),
        ),
      );

  @override
  Future<int> loadLamport() async {
    final row = await (_db.select(
      _db.metaRows,
    )..where((t) => t.k.equals('lamport'))).getSingleOrNull();
    return row == null ? 0 : int.parse(row.v);
  }

  @override
  Future<void> saveLamport(int value) => _db
      .into(_db.metaRows)
      .insertOnConflictUpdate(
        MetaRowsCompanion.insert(k: 'lamport', v: '$value'),
      );
}

class DriftPeerDirectory implements PeerDirectory {
  DriftPeerDirectory(this._db);
  final AppDatabase _db;

  @override
  Future<void> record(String addr, String name) => _db
      .into(_db.peerRows)
      .insertOnConflictUpdate(PeerRowsCompanion.insert(addr: addr, name: name));

  @override
  Future<String?> nameFor(String addr) async => (await (_db.select(
    _db.peerRows,
  )..where((t) => t.addr.equals(addr))).getSingleOrNull())?.name;
}
