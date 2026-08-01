import 'dart:convert';
import 'package:cash_me_outside/domain/canonical.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx({int amount = 500, String? memo, String type = txTypeMint}) =>
    Transaction(
        id: '01890000-0000-7000-8000-000000000001',
        type: type,
        from: 'AAA',
        to: 'AAA',
        amount: amount,
        memo: memo,
        lamportTs: 1,
        signature: 'sig');

void main() {
  test('canonical bytes: exact layout, sorted keys, memo:null when empty', () {
    expect(
        utf8.decode(canonicalBytesOf(tx())),
        '{"amount":500,"from":"AAA","id":"01890000-0000-7000-8000-000000000001",'
        '"lamportTs":1,"memo":null,"to":"AAA","type":"mint"}');
  });

  test('memo and unicode participate in the bytes', () {
    expect(canonicalBytesOf(tx(memo: 'pizza 🍕')),
        isNot(equals(canonicalBytesOf(tx()))));
  });

  test('signature is excluded: same fields different sig → same ledger key', () {
    final a = tx();
    final b = Transaction(
        id: a.id, type: a.type, from: a.from, to: a.to, amount: a.amount,
        memo: a.memo, lamportTs: a.lamportTs, signature: 'other');
    expect(ledgerKeyOf(a), ledgerKeyOf(b));
    expect(ledgerKeyOf(a), matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
