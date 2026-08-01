import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/domain/mesh/gossip_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const self = 'self-addr';

GossipEngine engine({Set<String>? initialSeen, DateTime Function()? now}) =>
    GossipEngine(selfAddr: self, initialSeen: initialSeen ?? {}, now: now);

MeshEnvelope env({
  String msgId = 'msg-1',
  String kind = envKindTx,
  String origin = 'origin-addr',
  String? target,
  int ttl = meshInitialTtl,
  List<String> path = const [],
  String payload = 'cmo:tx1:aaaa',
}) => MeshEnvelope(
  msgId: msgId,
  kind: kind,
  origin: origin,
  target: target,
  ttl: ttl,
  path: path,
  payload: payload,
);

void main() {
  test('dedupe: same frame twice → delivered once, no second relay', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.outboundFrames.listen(outbound.add);

    final frame = encodeFrame(env(target: null));
    e.onFrame(frame);
    e.onFrame(frame);

    expect(delivered.length, 1);
    expect(outbound.length, 1);
  });

  test('initialSeen pre-seeds the dedupe cache', () {
    final e = engine(initialSeen: {'msg-1'});
    final delivered = <MeshEnvelope>[];
    final seenAdditions = <String>[];
    e.delivered.listen(delivered.add);
    e.seenAdditions.listen(seenAdditions.add);

    e.onFrame(encodeFrame(env(msgId: 'msg-1', target: null)));

    expect(delivered, isEmpty);
    expect(seenAdditions, isEmpty);
  });

  test('seenAdditions emits msgId once per new frame, not on dedupe', () {
    final e = engine();
    final seen = <String>[];
    e.seenAdditions.listen(seen.add);
    final frame = encodeFrame(env(target: null));
    e.onFrame(frame);
    e.onFrame(frame);
    expect(seen, ['msg-1']);
  });

  test('broadcast → delivered AND relayed', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final relays = <RelayEvent>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.relays.listen(relays.add);
    e.outboundFrames.listen(outbound.add);

    e.onFrame(encodeFrame(env(target: null, ttl: 8)));

    expect(delivered.length, 1);
    expect(relays.length, 1);
    expect(outbound.length, 1);
  });

  test('targeted-at-self → delivered, NOT relayed', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final relays = <RelayEvent>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.relays.listen(relays.add);
    e.outboundFrames.listen(outbound.add);

    e.onFrame(encodeFrame(env(target: self, ttl: 8)));

    expect(delivered.length, 1);
    expect(relays, isEmpty);
    expect(outbound, isEmpty);
  });

  test('targeted-at-other → relayed only, RelayEvent fired', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final relays = <RelayEvent>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.relays.listen(relays.add);
    e.outboundFrames.listen(outbound.add);

    e.onFrame(encodeFrame(env(target: 'other-addr', ttl: 8)));

    expect(delivered, isEmpty);
    expect(relays.length, 1);
    expect(relays.single.envelope.msgId, 'msg-1');
    expect(outbound.length, 1);
  });

  test('ttl:1 → not relayed', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final relays = <RelayEvent>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.relays.listen(relays.add);
    e.outboundFrames.listen(outbound.add);

    e.onFrame(encodeFrame(env(target: null, ttl: 1)));

    expect(delivered.length, 1);
    expect(relays, isEmpty);
    expect(outbound, isEmpty);
  });

  test('unknown kind → relayed, never delivered', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final relays = <RelayEvent>[];
    final outbound = <String>[];
    e.delivered.listen(delivered.add);
    e.relays.listen(relays.add);
    e.outboundFrames.listen(outbound.add);

    e.onFrame(encodeFrame(env(kind: 'nonsense', target: null, ttl: 8)));

    expect(delivered, isEmpty);
    expect(relays.length, 1);
    expect(outbound.length, 1);
  });

  test('relay output frame has ttl-1 and self in path', () {
    final e = engine();
    final outbound = <String>[];
    e.outboundFrames.listen(outbound.add);

    e.onFrame(
      encodeFrame(env(target: 'other-addr', ttl: 8, path: const ['a'])),
    );

    expect(outbound.length, 1);
    final relayed = decodeFrame(outbound.single);
    expect(relayed.ttl, 7);
    expect(relayed.path, ['a', self]);
  });

  test(
    'originate targeted with hasConnectedPeers=false → outboxPuts fires with expiry now+24h',
    () {
      final fixedNow = DateTime.utc(2026, 8, 1, 12);
      final e = engine(now: () => fixedNow);
      final puts = <(String, String, DateTime)>[];
      final outbound = <String>[];
      e.outboxPuts.listen(puts.add);
      e.outboundFrames.listen(outbound.add);
      e.hasConnectedPeers = false;

      final envelope = env(target: 'other-addr', ttl: meshInitialTtl);
      e.originate(envelope);

      expect(outbound.length, 1);
      expect(puts.length, 1);
      expect(puts.single.$1, envelope.msgId);
      expect(puts.single.$3, fixedNow.add(const Duration(hours: 24)));
    },
  );

  test('originate targeted with hasConnectedPeers=true → no outbox put', () {
    final e = engine();
    final puts = <(String, String, DateTime)>[];
    final outbound = <String>[];
    e.outboxPuts.listen(puts.add);
    e.outboundFrames.listen(outbound.add);
    e.hasConnectedPeers = true;

    e.originate(env(target: 'other-addr'));

    expect(outbound.length, 1);
    expect(puts, isEmpty);
  });

  test('originate broadcast never puts to outbox regardless of peers', () {
    final e = engine();
    final puts = <(String, String, DateTime)>[];
    e.outboxPuts.listen(puts.add);
    e.hasConnectedPeers = false;

    e.originate(env(target: null));

    expect(puts, isEmpty);
  });

  test('receipt frame delivered to self → outboxClears emits its forMsgId', () {
    final e = engine();
    final clears = <String>[];
    final delivered = <MeshEnvelope>[];
    e.outboxClears.listen(clears.add);
    e.delivered.listen(delivered.add);

    final payload = receiptPayload('orig-msg-id', 2);
    e.onFrame(
      encodeFrame(
        env(kind: envKindReceipt, target: self, payload: payload, ttl: 8),
      ),
    );

    expect(clears, ['orig-msg-id']);
    expect(delivered.length, 1);
  });

  test('retransmit re-emits the frame unchanged (no ttl decrement)', () {
    final e = engine();
    final outbound = <String>[];
    e.outboundFrames.listen(outbound.add);

    final frame = encodeFrame(env(target: 'other-addr', ttl: 5));
    e.retransmit(frame);

    expect(outbound, [frame]);
  });

  test(
    'broadcast receipt-kind frame with garbage payload → no throw, '
    'relayed exactly once, nothing delivered',
    () {
      final e = engine();
      final delivered = <MeshEnvelope>[];
      final relays = <RelayEvent>[];
      final outbound = <String>[];
      final clears = <String>[];
      e.delivered.listen(delivered.add);
      e.relays.listen(relays.add);
      e.outboundFrames.listen(outbound.add);
      e.outboxClears.listen(clears.add);

      final frame = encodeFrame(
        env(kind: envKindReceipt, target: null, ttl: 8, payload: 'not json'),
      );

      expect(() => e.onFrame(frame), returnsNormally);

      expect(delivered, isEmpty);
      expect(clears, isEmpty);
      expect(relays.length, 1);
      expect(outbound.length, 1);
    },
  );

  test(
    'targeted-at-self tx-kind frame with garbage payload → no throw, '
    'still delivered (payload validation is the caller\'s job)',
    () {
      final e = engine();
      final delivered = <MeshEnvelope>[];
      final relays = <RelayEvent>[];
      e.delivered.listen(delivered.add);
      e.relays.listen(relays.add);

      final frame = encodeFrame(
        env(kind: envKindTx, target: self, ttl: 8, payload: 'not a tx'),
      );

      expect(() => e.onFrame(frame), returnsNormally);

      expect(delivered.length, 1);
      expect(relays, isEmpty); // targeted at self — never relayed
    },
  );

  test('malformed frame via onFrame → nothing emitted, no throw', () {
    final e = engine();
    final delivered = <MeshEnvelope>[];
    final outbound = <String>[];
    final relays = <RelayEvent>[];
    e.delivered.listen(delivered.add);
    e.outboundFrames.listen(outbound.add);
    e.relays.listen(relays.add);

    expect(() => e.onFrame('not json'), returnsNormally);

    expect(delivered, isEmpty);
    expect(outbound, isEmpty);
    expect(relays, isEmpty);
  });
}
