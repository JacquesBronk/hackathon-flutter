import 'dart:convert';
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

QrPayload decodeQr(String raw) {
  final parts = raw.split(':');
  if (parts.length != 3 || parts[0] != 'cmo') {
    throw QrDecodeException('not a pinnie code');
  }
  final Map<String, Object?> json;
  try {
    json = jsonDecode(utf8.decode(b64uDecode(parts[2])))
        as Map<String, Object?>;
  } catch (_) {
    throw QrDecodeException('not a pinnie code');
  }
  switch (parts[1]) {
    case 'rr1':
      final addr = json['addr'], name = json['name'], amount = json['amount'];
      if (addr is! String || name is! String ||
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
    default:
      throw QrDecodeException('not a pinnie code');
  }
}
