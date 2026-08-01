import 'dart:typed_data';
import 'keys.dart';
import 'ledger.dart';
import 'qr_codec.dart';
import 'transaction.dart';

/// Mint a voucher: owner signs a throwaway→ transfer, the throwaway's seed
/// travels inside the sticker payload so any claimant can sweep it later.
Future<(String voucherUri, Uint8List seed)> mintVoucher({
  required WalletKeys owner,
  required int amount,
  required int lamportTs,
}) async {
  final throwaway = await WalletKeys.generate();
  final seed = await throwaway.seed();
  final tx = await buildSigned(
    keys: owner,
    to: throwaway.address,
    amount: amount,
    type: txTypeTransfer,
    lamportTs: lamportTs,
  );
  final uri = encodeVoucher(VoucherPayload(tx: tx, seed: seed));
  return (uri, seed);
}

/// Reconstruct the throwaway keys from [voucher]'s seed and sign a fresh
/// throwaway→claimant sweep for the voucher's full amount.
Future<Transaction> buildSweep({
  required VoucherPayload voucher,
  required String claimant,
  required int lamportTs,
}) async {
  final throwaway = await WalletKeys.fromSeed(voucher.seed);
  return buildSigned(
    keys: throwaway,
    to: claimant,
    amount: voucher.tx.amount,
    type: txTypeTransfer,
    lamportTs: lamportTs,
  );
}

/// Ingest the voucher's inner tx, then sign+ingest the sweep. Null on
/// validation failure. Re-claiming an already-ingested voucher tx (duplicate)
/// is not a failure — it's the sanctioned double-claim path; a fresh sweep is
/// still built and ingested for this claimant.
Future<(Transaction voucherTx, Transaction sweepTx)?> claimVoucher({
  required Ledger ledger,
  required VoucherPayload voucher,
  required String claimant,
  required int lamportTs,
}) async {
  final voucherResult = await ledger.ingest(voucher.tx);
  if (voucherResult.status == IngestStatus.rejected) return null;
  final sweep = await buildSweep(
    voucher: voucher,
    claimant: claimant,
    lamportTs: lamportTs,
  );
  final sweepResult = await ledger.ingest(sweep);
  if (sweepResult.status != IngestStatus.added) return null;
  return (voucher.tx, sweep);
}
