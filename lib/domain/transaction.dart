const txTypeMint = 'mint';
const txTypeTransfer = 'transfer';

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    required this.lamportTs,
    required this.signature,
  });

  final String id; // lowercase canonical UUIDv7
  final String type;
  final String from; // address
  final String to; // address
  final int amount; // integer pinnies
  final String? memo;
  final int lamportTs;
  final String signature; // b64u(64 bytes)

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'from': from,
    'to': to,
    'amount': amount,
    'memo': memo,
    'lamportTs': lamportTs,
    'signature': signature,
  };

  factory Transaction.fromJson(Map<String, Object?> json) {
    final id = json['id'],
        type = json['type'],
        from = json['from'],
        to = json['to'],
        amount = json['amount'],
        memo = json['memo'],
        lamportTs = json['lamportTs'],
        signature = json['signature'];
    if (id is! String ||
        type is! String ||
        from is! String ||
        to is! String ||
        amount is! int ||
        lamportTs is! int ||
        signature is! String ||
        (memo != null && memo is! String)) {
      throw const FormatException('malformed transaction');
    }
    return Transaction(
      id: id,
      type: type,
      from: from,
      to: to,
      amount: amount,
      memo: memo as String?,
      lamportTs: lamportTs,
      signature: signature,
    );
  }
}
