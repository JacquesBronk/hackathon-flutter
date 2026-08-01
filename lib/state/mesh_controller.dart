import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:uuid/uuid.dart';
import '../domain/mesh/envelope.dart';
import '../domain/mesh/gossip_engine.dart';
import '../domain/qr_codec.dart';
import '../ports/mesh_transport.dart';
import '../ports/notifier.dart';
import '../ports/outbox_store.dart';
import '../providers.dart';

const _uuid = Uuid();

enum MeshDeliveryStatus { hopping, delivered }

class MeshState {
  const MeshState({required this.livePeers, required this.deliveries});
  final List<MeshPeer> livePeers;
  final Map<String, MeshDeliveryStatus> deliveries; // keyed by tx id
}

/// Wires a transport-agnostic [GossipEngine] to a [MeshTransport] and the
/// rest of the app (ledger, peer directory, notifications, persistence).
/// No periodic timers here — callers (A6's real wiring) own the cadence via
/// [broadcastPresenceOnce] / [flushOutboxOnce].
class MeshController extends AsyncNotifier<MeshState> {
  late final GossipEngine _engine;
  late final MeshTransport _transport;
  late final OutboxStore _outboxStore;
  late final Notifier _notifier;
  late final String _selfAddr;

  /// Relay traffic this node forwards for others — only meaningful once
  /// [build] has completed (e.g. after `await future`); the radar screen's
  /// pulse animation is fed from this.
  Stream<RelayEvent> get relays => _engine.relays;

  final _peersByAddr = <String, MeshPeer>{};
  // envelope msgId of an originated `tx` -> that transaction's id, so a
  // later receipt (keyed by the envelope msgId) can update `deliveries`
  // (keyed by tx id per the binding resolution — History needs tx id).
  final _txEnvelopeToTxId = <String, String>{};

  @override
  Future<MeshState> build() async {
    _transport = ref.read(meshTransportProvider);
    _outboxStore = ref.read(outboxStoreProvider);
    _notifier = ref.read(notifierProvider);
    final seenStore = ref.read(seenStoreProvider);
    _selfAddr = (await ref.read(walletKeysProvider.future))!.address;

    _engine = GossipEngine(
      selfAddr: _selfAddr,
      initialSeen: await seenStore.load(),
    );

    final subs = <StreamSubscription<Object?>>[
      _engine.outboundFrames.listen(_transport.broadcastFrame),
      _engine.seenAdditions.listen(seenStore.add),
      _engine.outboxPuts.listen((e) => _outboxStore.put(e.$1, e.$2, e.$3)),
      _engine.outboxClears.listen(_outboxStore.remove),
      _engine.delivered.listen(_handleDelivered),
      _engine.relays.listen(_handleRelay),
      _transport.inboundFrames.listen(_engine.onFrame),
      _transport.peerEvents.listen(_handlePeerEvent),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    });

    return const MeshState(livePeers: [], deliveries: {});
  }

  /// Payload parsing (decodeQr / parsePresencePayload / parseReceiptPayload)
  /// is untrusted input off the wire — a malformed payload must drop
  /// silently, never crash this listener.
  Future<void> _handleDelivered(MeshEnvelope envelope) async {
    try {
      switch (envelope.kind) {
        case envKindTx:
          final payload = decodeQr(envelope.payload);
          if (payload is! SignedTransactionPayload) return;
          final tx = payload.transaction;
          await ref
              .read(ledgerControllerProvider.notifier)
              .ingestExternal(tx);
          _engine.originate(
            MeshEnvelope(
              msgId: _uuid.v7(),
              kind: envKindReceipt,
              origin: _selfAddr,
              target: envelope.origin,
              ttl: meshInitialTtl,
              path: const [],
              payload: receiptPayload(envelope.msgId, envelope.path.length),
            ),
          );
          await _notifier.show(
            id: _notifId(envelope.msgId),
            title: 'Pinnies received',
            body: 'ᵽ${tx.amount} arrived via the mesh',
          );
        case envKindPresence:
          final p = parsePresencePayload(envelope.payload);
          await ref.read(peerDirectoryProvider).record(p.addr, p.name);
        case envKindReceipt:
          final (forMsgId, hops) = parseReceiptPayload(envelope.payload);
          final txId = _txEnvelopeToTxId[forMsgId];
          if (txId == null) return;
          _setDelivery(txId, MeshDeliveryStatus.delivered);
          await _notifier.show(
            id: _notifId(forMsgId),
            title: 'Delivered',
            body: 'arrived via $hops phones',
          );
        default:
          break; // chat/pour reserved, no handling yet
      }
    } catch (_) {
      // malformed payload — silent drop.
    }
  }

  void _handleRelay(RelayEvent event) {
    if (event.envelope.kind != envKindTx) return; // silent for presence etc.
    final Object? payload;
    try {
      payload = decodeQr(event.envelope.payload);
    } catch (_) {
      return; // malformed payload — silent drop.
    }
    if (payload is! SignedTransactionPayload) return;
    unawaited(
      _notifier.show(
        id: _notifId(event.envelope.msgId),
        title: 'Relayed',
        body:
            'your phone just relayed ᵽ${payload.transaction.amount} for a '
            'stranger 🕵️',
      ),
    );
  }

  void _handlePeerEvent(MeshPeer peer) {
    _peersByAddr[peer.addr] = peer;
    _engine.hasConnectedPeers = true;
    state = AsyncData(
      MeshState(
        livePeers: _peersByAddr.values.toList(),
        deliveries: state.valueOrNull?.deliveries ?? const {},
      ),
    );
    unawaited(flushOutboxOnce());
  }

  void _setDelivery(String txId, MeshDeliveryStatus status) {
    final current =
        state.valueOrNull ?? const MeshState(livePeers: [], deliveries: {});
    state = AsyncData(
      MeshState(
        livePeers: current.livePeers,
        deliveries: {...current.deliveries, txId: status},
      ),
    );
  }

  int _notifId(String seed) => seed.hashCode & 0x7fffffff;

  /// Sends [amount] to [to] via the existing biometric-gated ledger flow,
  /// then gossips the signed tx. Returns the transaction id (deliveries are
  /// keyed by tx id, not envelope msgId).
  Future<String> sendMeshTx({
    required String to,
    required int amount,
    String? memo,
  }) async {
    await future;
    final tx = await ref
        .read(ledgerControllerProvider.notifier)
        .send(to: to, amount: amount, memo: memo);
    final envelope = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindTx,
      origin: _selfAddr,
      target: to,
      ttl: meshInitialTtl,
      path: const [],
      payload: encodeTransaction(tx),
    );
    _txEnvelopeToTxId[envelope.msgId] = tx.id;
    _engine.originate(envelope);
    _setDelivery(tx.id, MeshDeliveryStatus.hopping);
    return tx.id;
  }

  Future<void> broadcastPresenceOnce() async {
    await future;
    final profile = await ref.read(profileControllerProvider.future);
    _engine.originate(
      MeshEnvelope(
        msgId: _uuid.v7(),
        kind: envKindPresence,
        origin: _selfAddr,
        target: null,
        ttl: meshInitialTtl,
        path: const [],
        payload: presencePayload(_selfAddr, profile?.name ?? ''),
      ),
    );
  }

  Future<void> flushOutboxOnce() async {
    await future;
    for (final (_, frame) in await _outboxStore.pending()) {
      _engine.retransmit(frame);
    }
  }
}
