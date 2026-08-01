import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/canonical.dart';
import '../domain/ledger.dart';
import '../domain/transaction.dart';
import '../providers.dart';

class LedgerState {
  const LedgerState({required this.balances, required this.ordered});
  final Map<String, int> balances;
  final List<Transaction> ordered;
}

class LedgerController extends AsyncNotifier<LedgerState> {
  final _ledger = Ledger();
  LamportClock _clock = LamportClock();
  Future<void>? _ready;

  Future<void> _init() async {
    final store = ref.read(ledgerStoreProvider);
    for (final tx in await store.loadAll()) {
      await _ledger.ingest(
        tx,
      ); // re-validates persisted data (defense in depth)
    }
    _clock = LamportClock(await store.loadLamport());
  }

  /// Mutating methods race build(): createWallet → mintSelf fires while the
  /// first build is still mid-flight. Every mutator awaits this first.
  Future<void> _ensureReady() => _ready ??= _init();

  @override
  Future<LedgerState> build() async {
    await _ensureReady();
    return _snapshot();
  }

  LedgerState _snapshot() =>
      LedgerState(balances: _ledger.balances(), ordered: _ledger.ordered);

  Future<IngestResult> ingestExternal(Transaction tx) async {
    await _ensureReady();
    final result = await _ledger.ingest(tx);
    if (result.status == IngestStatus.added) {
      final store = ref.read(ledgerStoreProvider);
      await store.save(tx);
      _clock.next(_ledger.highestLamport); // observe remote clocks
      await store.saveLamport(_clock.value);
      state = AsyncData(_snapshot());
    }
    return result;
  }

  Future<Transaction> send({
    required String to,
    required int amount,
    String? memo,
  }) async {
    await _ensureReady();
    final keys = (await ref.read(walletKeysProvider.future))!;
    final tx = await buildSigned(
      keys: keys,
      to: to,
      amount: amount,
      memo: (memo == null || memo.isEmpty) ? null : memo, // '' never signed
      type: txTypeTransfer,
      lamportTs: _clock.next(_ledger.highestLamport),
    );
    // Sender ingests at signing time (spec §4.3) — stranded delivery is
    // recovered by re-showing the tx QR from History.
    final result = await _ledger.ingest(tx);
    if (result.status != IngestStatus.added) {
      // A real thrown error, not a debug assert: a rejected transaction must
      // never persist, in release builds included.
      throw StateError('send rejected: ${result.reason}');
    }
    final store = ref.read(ledgerStoreProvider);
    await store.save(tx);
    await store.saveLamport(_clock.value);
    state = AsyncData(_snapshot());
    return tx;
  }

  Future<void> mintSelf() async {
    await _ensureReady();
    final keys = (await ref.read(walletKeysProvider.future))!;
    final tx = await buildSigned(
      keys: keys,
      to: keys.address,
      amount: mintAmount,
      type: txTypeMint,
      lamportTs: _clock.next(_ledger.highestLamport),
    );
    await _ledger.ingest(tx);
    final store = ref.read(ledgerStoreProvider);
    await store.save(tx);
    await store.saveLamport(_clock.value);
    state = AsyncData(_snapshot());
  }
}
