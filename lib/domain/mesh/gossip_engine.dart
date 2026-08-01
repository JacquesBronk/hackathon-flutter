import 'dart:async';

import 'envelope.dart';

const _knownKinds = {
  envKindTx,
  envKindPresence,
  envKindReceipt,
  envKindChat,
  envKindPour,
};

class RelayEvent {
  const RelayEvent({required this.envelope});
  final MeshEnvelope envelope;
}

/// Transport-agnostic flood/TTL gossip pipeline (spec §2.2). Pure Dart —
/// no Flutter, no port imports. Callers wire streams to a transport and
/// persistence; the engine itself holds only in-memory dedupe state.
class GossipEngine {
  GossipEngine({
    required this.selfAddr,
    required Set<String> initialSeen,
    DateTime Function()? now,
  }) : _seen = {...initialSeen},
       _now = now ?? DateTime.now;

  final String selfAddr;
  final DateTime Function() _now;
  final Set<String> _seen;

  bool hasConnectedPeers = false;

  final _delivered = StreamController<MeshEnvelope>.broadcast(sync: true);
  final _outboundFrames = StreamController<String>.broadcast(sync: true);
  final _relays = StreamController<RelayEvent>.broadcast(sync: true);
  final _seenAdditions = StreamController<String>.broadcast(sync: true);
  final _outboxPuts = StreamController<(String, String, DateTime)>.broadcast(
    sync: true,
  );
  final _outboxClears = StreamController<String>.broadcast(sync: true);

  Stream<MeshEnvelope> get delivered => _delivered.stream;
  Stream<String> get outboundFrames => _outboundFrames.stream;
  Stream<RelayEvent> get relays => _relays.stream;
  Stream<String> get seenAdditions => _seenAdditions.stream;
  Stream<(String msgId, String frame, DateTime expiresAt)> get outboxPuts =>
      _outboxPuts.stream;
  Stream<String> get outboxClears => _outboxClears.stream;

  void onFrame(String frameJson) {
    final MeshEnvelope envelope;
    try {
      envelope = decodeFrame(frameJson);
    } on FrameDecodeException {
      return;
    }

    if (_seen.contains(envelope.msgId)) return;
    _seen.add(envelope.msgId);
    _seenAdditions.add(envelope.msgId);

    // Relay is decided from envelope fields ONLY — payload is opaque to
    // relays, so a garbage payload must still relay (spec §2.2 rule 4).
    if (envelope.ttl > 1 && envelope.target != selfAddr) {
      final relayed = envelope.relayedBy(selfAddr);
      _relays.add(RelayEvent(envelope: envelope));
      _outboundFrames.add(encodeFrame(relayed));
      if (relayed.target != null && !hasConnectedPeers) {
        _outboxPuts.add((
          relayed.msgId,
          encodeFrame(relayed),
          _now().add(const Duration(hours: 24)),
        ));
      }
    }

    final isForSelf = envelope.target == null || envelope.target == selfAddr;
    if (isForSelf && _knownKinds.contains(envelope.kind)) {
      try {
        _deliverLocally(envelope);
      } catch (_) {
        // malformed payload — silent drop, never throw out of onFrame.
      }
    }
  }

  void _deliverLocally(MeshEnvelope envelope) {
    if (envelope.kind == envKindReceipt) {
      // Parse before publishing delivery so a malformed receipt payload
      // drops silently instead of surfacing a delivery no one can read.
      final (forMsgId, _) = parseReceiptPayload(envelope.payload);
      _delivered.add(envelope);
      _outboxClears.add(forMsgId);
    } else {
      _delivered.add(envelope);
    }
  }

  void originate(MeshEnvelope e) {
    _seen.add(e.msgId);
    final frame = encodeFrame(e);
    _outboundFrames.add(frame);
    if (e.target != null && !hasConnectedPeers) {
      _outboxPuts.add((e.msgId, frame, _now().add(const Duration(hours: 24))));
    }
  }

  void retransmit(String frame) {
    _outboundFrames.add(frame);
  }
}
