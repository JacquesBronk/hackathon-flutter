import 'package:drift/drift.dart';
import 'drift_db.dart';
import '../ports/outbox_store.dart';
import '../ports/seen_store.dart';

class DriftOutboxStore implements OutboxStore {
  DriftOutboxStore(this._db);
  final AppDatabase _db;

  @override
  Future<void> put(String msgId, String frameJson, DateTime expiresAt) => _db
      .into(_db.outboxRows)
      .insertOnConflictUpdate(
        OutboxRowsCompanion.insert(
          msgId: msgId,
          frameJson: frameJson,
          expiresAt: expiresAt,
        ),
      );

  @override
  Future<void> remove(String msgId) =>
      (_db.delete(_db.outboxRows)..where((t) => t.msgId.equals(msgId))).go();

  @override
  Future<List<(String, String)>> pending() async {
    await (_db.delete(
      _db.outboxRows,
    )..where((t) => t.expiresAt.isSmallerThanValue(DateTime.now()))).go();
    final rows = await _db.select(_db.outboxRows).get();
    return rows.map((r) => (r.msgId, r.frameJson)).toList();
  }
}

/// Caps at 1024 entries (LRU by insertion order via `seq`); a full drift
/// adapter beyond the fake's unbounded set (see SeenStore port docs).
class DriftSeenStore implements SeenStore {
  DriftSeenStore(this._db);
  final AppDatabase _db;
  static const _cap = 1024;

  @override
  Future<Set<String>> load() async {
    final rows = await _db.select(_db.seenRows).get();
    return rows.map((r) => r.msgId).toSet();
  }

  @override
  Future<void> add(String msgId) async {
    final exists = await (_db.select(
      _db.seenRows,
    )..where((t) => t.msgId.equals(msgId))).getSingleOrNull();
    if (exists != null) return;
    await _db.into(_db.seenRows).insert(SeenRowsCompanion.insert(msgId: msgId));
    final overflow = await _db.seenRows.count().getSingle() - _cap;
    if (overflow <= 0) return;
    final oldest =
        await (_db.select(_db.seenRows)
              ..orderBy([(t) => OrderingTerm.asc(t.seq)])
              ..limit(overflow))
            .get();
    for (final row in oldest) {
      await (_db.delete(
        _db.seenRows,
      )..where((t) => t.seq.equals(row.seq))).go();
    }
  }
}
