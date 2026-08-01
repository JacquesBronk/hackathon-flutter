import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ledger.dart';
import '../domain/qr_codec.dart';
import '../domain/voucher.dart';
import '../ports/nfc_port.dart';
import '../providers.dart';

class NfcState {
  const NfcState({required this.tapModeActive, this.lastClaimAmount});
  final bool tapModeActive;
  final int? lastClaimAmount; // most recent successful voucher claim

  NfcState copyWith({bool? tapModeActive, int? lastClaimAmount}) => NfcState(
    tapModeActive: tapModeActive ?? this.tapModeActive,
    lastClaimAmount: lastClaimAmount ?? this.lastClaimAmount,
  );
}

/// Wires an [NfcPort] to the app: tap-mode HCE broadcasts this wallet's own
/// receive request; reads dispatch by decoded kind to the existing flows
/// (rr → send confirm via [sendRequests], tx1 → ledger ingest, v1 → claim).
class NfcController extends AsyncNotifier<NfcState> {
  late final NfcPort _nfcPort;

  final _sendRequests = StreamController<ReceiveRequest>.broadcast();

  /// Emits rr reads for the UI to route into the existing send-confirm flow.
  Stream<ReceiveRequest> get sendRequests => _sendRequests.stream;

  @override
  Future<NfcState> build() async {
    _nfcPort = ref.read(nfcPortProvider);
    final sub = _nfcPort.tagsRead.listen(_handleRead);
    ref.onDispose(() => unawaited(sub.cancel()));
    return const NfcState(tapModeActive: false);
  }

  /// Payload parsing is untrusted input off the tag — malformed/unknown must
  /// drop silently, never crash this listener (mirrors mesh's rule).
  Future<void> _handleRead(String raw) async {
    final QrPayload payload;
    try {
      payload = decodeQr(raw);
    } on QrDecodeException {
      return;
    }
    switch (payload) {
      case ReceiveRequest rr:
        _sendRequests.add(rr);
      case SignedTransactionPayload stp:
        await ref
            .read(ledgerControllerProvider.notifier)
            .ingestExternal(stp.transaction);
      case VoucherPayload voucher:
        await _claim(voucher);
    }
  }

  /// Bridges C1's pure-domain claimVoucher orchestration into the app's
  /// LedgerController (persist to store, advance lamport clock, update
  /// state) the same way ingestExternal already does for mesh-delivered txs.
  Future<void> _claim(VoucherPayload voucher) async {
    final ledger = ref.read(ledgerControllerProvider.notifier);
    final voucherResult = await ledger.ingestExternal(voucher.tx);
    if (voucherResult.status == IngestStatus.rejected) return;
    final selfAddr = (await ref.read(walletKeysProvider.future))!.address;
    final sweep = await buildSweep(
      voucher: voucher,
      claimant: selfAddr,
      lamportTs: await _nextLamportTs(),
    );
    final sweepResult = await ledger.ingestExternal(sweep);
    if (sweepResult.status != IngestStatus.added) return;
    state = AsyncData(
      (state.valueOrNull ?? const NfcState(tapModeActive: false)).copyWith(
        lastClaimAmount: voucher.tx.amount,
      ),
    );
  }

  Future<int> _nextLamportTs() async {
    final ledgerState = await ref.read(ledgerControllerProvider.future);
    if (ledgerState.ordered.isEmpty) return 1;
    return ledgerState.ordered.map((t) => t.lamportTs).reduce(math.max) + 1;
  }

  /// Starts an HCE session carrying this wallet's own `cmo:rr1:` request.
  Future<void> enableTapMode({int? amount}) async {
    await future;
    final keys = (await ref.read(walletKeysProvider.future))!;
    final profile = await ref.read(profileControllerProvider.future);
    final uri = encodeReceiveRequest(
      ReceiveRequest(
        addr: keys.address,
        name: profile?.name ?? '',
        amount: amount,
      ),
    );
    await _nfcPort.startHceSession(uri);
    state = AsyncData(state.requireValue.copyWith(tapModeActive: true));
  }

  Future<void> disableTapMode() async {
    await future;
    await _nfcPort.stopHceSession();
    state = AsyncData(state.requireValue.copyWith(tapModeActive: false));
  }

  /// Writes a `cmo:rr1:` payment-request tag ("pay the owner" sticker).
  Future<void> writeRequestTag({int? amount}) async {
    await future;
    final keys = (await ref.read(walletKeysProvider.future))!;
    final profile = await ref.read(profileControllerProvider.future);
    final uri = encodeReceiveRequest(
      ReceiveRequest(
        addr: keys.address,
        name: profile?.name ?? '',
        amount: amount,
      ),
    );
    await _nfcPort.writeTag(uri);
  }

  /// Writes a claimable voucher tag — this signs money away, so it is
  /// biometric-gated like any other outgoing transfer. Returns false without
  /// writing anything if the gate denies.
  Future<bool> writeVoucherTag(int amount) async {
    await future;
    final approved = await ref
        .read(biometricGateProvider)
        .authenticate('Confirm putting ᵽ$amount on a voucher tag');
    if (!approved) return false;
    final keys = (await ref.read(walletKeysProvider.future))!;
    final (uri, _) = await mintVoucher(
      owner: keys,
      amount: amount,
      lamportTs: await _nextLamportTs(),
    );
    await _nfcPort.writeTag(uri);
    return true;
  }
}
