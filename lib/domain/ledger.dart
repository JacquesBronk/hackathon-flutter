import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'canonical.dart';
import 'keys.dart';
import 'transaction.dart';

enum IngestStatus { added, duplicate, rejected }

class IngestResult {
  const IngestResult(this.status, [this.reason]);
  final IngestStatus status;
  final String? reason;
}

class LamportClock {
  LamportClock([this._value = 0]);
  int _value;
  int get value => _value;
  int next(int highestSeen) => _value = math.max(_value, highestSeen) + 1;
}

/// Grow-only CRDT set keyed on sha256(canonical bytes) — spec §2.2.
class Ledger {
  final Map<String, Transaction> _byKey = {};

  /// Deterministic total replay order: (lamportTs, id), id bytewise.
  List<Transaction> get ordered {
    final list = _byKey.values.toList();
    list.sort((a, b) {
      final c = a.lamportTs.compareTo(b.lamportTs);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  int get highestLamport =>
      _byKey.values.fold(0, (m, t) => math.max(m, t.lamportTs));

  Future<IngestResult> ingest(Transaction tx) async {
    final key = ledgerKeyOf(tx);
    if (_byKey.containsKey(key)) {
      return const IngestResult(IngestStatus.duplicate);
    }
    if (tx.amount < 1 || tx.amount > maxAmount) {
      return const IngestResult(IngestStatus.rejected, 'amount out of range');
    }
    if (tx.type == txTypeMint &&
        (tx.from != tx.to || tx.amount != mintAmount)) {
      return const IngestResult(IngestStatus.rejected, 'invalid mint');
    }
    final ok = await verifyTransactionSignature(
      from: tx.from,
      canonicalBytes: canonicalBytesOf(tx),
      signature: tx.signature,
    );
    if (!ok) return const IngestResult(IngestStatus.rejected, 'bad signature');
    _byKey[key] = tx;
    return const IngestResult(IngestStatus.added);
  }

  /// Replay in total order. Unknown types are retained but ignored.
  /// At most one mint per address counts (first in replay order).
  Map<String, int> balances() {
    final bal = <String, int>{};
    final minted = <String>{};
    for (final tx in ordered) {
      switch (tx.type) {
        case txTypeMint:
          if (minted.add(tx.from)) {
            bal[tx.to] = (bal[tx.to] ?? 0) + tx.amount;
          }
        case txTypeTransfer:
          bal[tx.from] = (bal[tx.from] ?? 0) - tx.amount;
          bal[tx.to] = (bal[tx.to] ?? 0) + tx.amount;
        default:
          break; // forward-compat: ignore
      }
    }
    return bal;
  }
}

/// Create + sign a transaction with [keys] as sender.
Future<Transaction> buildSigned({
  required WalletKeys keys,
  required String to,
  required int amount,
  String? memo,
  required String type,
  required int lamportTs,
  String? id,
}) async {
  final unsigned = Transaction(
    id: id ?? const Uuid().v7(),
    type: type,
    from: keys.address,
    to: to,
    amount: amount,
    memo: memo,
    lamportTs: lamportTs,
    signature: '',
  );
  final sig = await keys.sign(canonicalBytesOf(unsigned));
  return Transaction(
    id: unsigned.id,
    type: type,
    from: keys.address,
    to: to,
    amount: amount,
    memo: memo,
    lamportTs: lamportTs,
    signature: sig,
  );
}
