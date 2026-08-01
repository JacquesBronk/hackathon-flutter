import 'dart:convert';

import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MeshEnvelope sample({
    String? target,
    int ttl = meshInitialTtl,
    List<String> path = const [],
  }) => MeshEnvelope(
    msgId: '01890a5d-ac96-774b-bcce-b302099a8057',
    kind: envKindTx,
    origin: 'origin-addr',
    target: target,
    ttl: ttl,
    path: path,
    payload: 'cmo:tx1:aaaa',
  );

  test('toJson has exact layout and key order', () {
    final json = sample(target: 'target-addr', path: const ['relay1']).toJson();
    expect(json.keys.toList(), [
      'v',
      'msgId',
      'kind',
      'origin',
      'target',
      'ttl',
      'path',
      'payload',
    ]);
    expect(json, {
      'v': 1,
      'msgId': '01890a5d-ac96-774b-bcce-b302099a8057',
      'kind': 'tx',
      'origin': 'origin-addr',
      'target': 'target-addr',
      'ttl': meshInitialTtl,
      'path': ['relay1'],
      'payload': 'cmo:tx1:aaaa',
    });
  });

  test('round trips through toJson/fromJson and encodeFrame/decodeFrame', () {
    for (final target in [null, 'target-addr']) {
      final e = sample(target: target, path: const ['relay1', 'relay2']);
      final decoded = MeshEnvelope.fromJson(e.toJson());
      expect(decoded.toJson(), e.toJson());

      final frame = encodeFrame(e);
      final decodedFrame = decodeFrame(frame);
      expect(decodedFrame.toJson(), e.toJson());
    }
  });

  test('encodeFrame produces compact JSON (no extra whitespace)', () {
    final frame = encodeFrame(sample(target: null));
    expect(frame.contains(' '), isFalse);
    expect(jsonDecode(frame), sample(target: null).toJson());
  });

  test('fromJson rejects missing field', () {
    final json = sample(target: null).toJson()..remove('origin');
    expect(() => MeshEnvelope.fromJson(json), throwsFormatException);
  });

  test('fromJson rejects wrong version', () {
    final json = sample(target: null).toJson();
    json['v'] = 2;
    expect(() => MeshEnvelope.fromJson(json), throwsFormatException);
  });

  test('fromJson rejects non-int ttl', () {
    final json = sample(target: null).toJson();
    json['ttl'] = 'eight';
    expect(() => MeshEnvelope.fromJson(json), throwsFormatException);
  });

  test('fromJson rejects non-list path', () {
    final json = sample(target: null).toJson();
    json['path'] = 'not-a-list';
    expect(() => MeshEnvelope.fromJson(json), throwsFormatException);
  });

  test('fromJson rejects path with non-string elements', () {
    final json = sample(target: null).toJson();
    json['path'] = [1, 2];
    expect(() => MeshEnvelope.fromJson(json), throwsFormatException);
  });

  test('fromJson accepts null target (broadcast)', () {
    final json = sample(target: null).toJson();
    final decoded = MeshEnvelope.fromJson(json);
    expect(decoded.target, isNull);
  });

  test('decodeFrame throws FrameDecodeException on malformed JSON', () {
    for (final bad in ['not json', '{', '[]', '"a string"', '']) {
      expect(
        () => decodeFrame(bad),
        throwsA(isA<FrameDecodeException>()),
        reason: bad,
      );
    }
  });

  test(
    'decodeFrame throws FrameDecodeException on valid JSON, bad envelope',
    () {
      expect(
        () => decodeFrame(jsonEncode({'v': 1})),
        throwsA(isA<FrameDecodeException>()),
      );
    },
  );

  test('relayedBy decrements ttl and appends self to path', () {
    final e = sample(target: 'target-addr', ttl: 8, path: const ['a', 'b']);
    final relayed = e.relayedBy('self-addr');
    expect(relayed.ttl, 7);
    expect(relayed.path, ['a', 'b', 'self-addr']);
    expect(relayed.msgId, e.msgId);
    expect(relayed.origin, e.origin);
    expect(relayed.target, e.target);
    expect(relayed.payload, e.payload);
    // original unchanged (immutable)
    expect(e.ttl, 8);
    expect(e.path, ['a', 'b']);
  });

  test('receiptPayload/parseReceiptPayload round trip', () {
    final payload = receiptPayload('msg-123', 3);
    final (forMsgId, hops) = parseReceiptPayload(payload);
    expect(forMsgId, 'msg-123');
    expect(hops, 3);
  });

  test('parseReceiptPayload throws FormatException on malformed input', () {
    for (final bad in [
      'not json',
      '{}',
      '{"forMsgId":"x"}',
      '{"forMsgId":1,"hops":2}',
    ]) {
      expect(
        () => parseReceiptPayload(bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  test('presencePayload/parsePresencePayload round trip', () {
    final payload = presencePayload('addr-1', 'Thabo');
    final parsed = parsePresencePayload(payload);
    expect(parsed.addr, 'addr-1');
    expect(parsed.name, 'Thabo');
  });

  test('parsePresencePayload throws FormatException on malformed input', () {
    for (final bad in [
      'not json',
      '{}',
      '{"addr":"a"}',
      '{"addr":1,"name":"x"}',
    ]) {
      expect(
        () => parsePresencePayload(bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });
}
