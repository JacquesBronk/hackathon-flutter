import 'dart:convert';
import 'dart:typed_data';
import 'keys.dart';
import 'transaction.dart';

sealed class QrPayload {}

class ReceiveRequest extends QrPayload {
  ReceiveRequest({required this.addr, required this.name, this.amount});
  final String addr;
  final String name; // UNAUTHENTICATED — UI must show truncated addr alongside
  final int? amount;
}

class SignedTransactionPayload extends QrPayload {
  SignedTransactionPayload(this.transaction);
  final Transaction transaction;
}

/// Voucher sticker payload ("stick ᵽ50 under a chair") — spec §4. `tx` pays a
/// throwaway address; `seed` reconstructs that throwaway's keys for the
/// sweep. Double-claim is a sanctioned feature, not a bug: this codec never
/// enforces exclusivity.
class VoucherPayload extends QrPayload {
  VoucherPayload({required this.tx, required this.seed});
  final Transaction tx;
  final Uint8List seed;
}

class QrDecodeException implements Exception {
  QrDecodeException(this.message);
  final String message;
}

String _wrap(String kind, Map<String, Object?> json) =>
    'cmo:$kind:${b64u(utf8.encode(jsonEncode(json)))}';

String encodeReceiveRequest(ReceiveRequest rr) => _wrap('rr1', {
  'addr': rr.addr,
  'name': rr.name,
  if (rr.amount != null) 'amount': rr.amount,
});

String encodeTransaction(Transaction tx) => _wrap('tx1', tx.toJson());

String encodeVoucher(VoucherPayload voucher) => _wrap('v1', {
  'tx': encodeTransaction(voucher.tx),
  'seed': b64u(voucher.seed),
});

QrPayload decodeQr(String raw) {
  final parts = raw.split(':');
  if (parts.length != 3 || parts[0] != 'cmo') {
    throw QrDecodeException('not a pinnie code');
  }
  final Map<String, Object?> json;
  try {
    json =
        jsonDecode(utf8.decode(b64uDecode(parts[2]))) as Map<String, Object?>;
  } catch (_) {
    throw QrDecodeException('not a pinnie code');
  }
  switch (parts[1]) {
    case 'rr1':
      final addr = json['addr'], name = json['name'], amount = json['amount'];
      if (addr is! String ||
          name is! String ||
          (amount != null && amount is! int)) {
        throw QrDecodeException('not a pinnie code');
      }
      return ReceiveRequest(addr: addr, name: name, amount: amount as int?);
    case 'tx1':
      try {
        return SignedTransactionPayload(Transaction.fromJson(json));
      } on FormatException {
        throw QrDecodeException('not a pinnie code');
      }
    case 'v1':
      final tx = json['tx'], seed = json['seed'];
      if (tx is! String || seed is! String) {
        throw QrDecodeException('not a pinnie code');
      }
      final Uint8List seedBytes;
      try {
        seedBytes = b64uDecode(seed);
      } catch (_) {
        throw QrDecodeException('not a pinnie code');
      }
      if (seedBytes.length != 32) {
        throw QrDecodeException('not a pinnie code');
      }
      final inner = decodeQr(tx);
      if (inner is! SignedTransactionPayload) {
        throw QrDecodeException('not a pinnie code');
      }
      return VoucherPayload(tx: inner.transaction, seed: seedBytes);
    default:
      throw QrDecodeException('not a pinnie code');
  }
}
