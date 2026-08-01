import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'transaction.dart';

const int mintAmount = 500; // protocol constant — replay-enforced
const int maxAmount = 9007199254740991; // 2^53 - 1, web-safe

/// Pinned canonicalizer (spec §2.1): keys inserted in this exact order,
/// memo ALWAYS present (null when empty), jsonEncode, UTF-8.
Uint8List canonicalBytesOf(Transaction tx) {
  final map = <String, Object?>{
    'amount': tx.amount,
    'from': tx.from,
    'id': tx.id,
    'lamportTs': tx.lamportTs,
    'memo': tx.memo,
    'to': tx.to,
    'type': tx.type,
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(map)));
}

/// Ledger set key: id collisions must not fork the CRDT (spec §2.2).
String ledgerKeyOf(Transaction tx) =>
    sha256.convert(canonicalBytesOf(tx)).toString();
