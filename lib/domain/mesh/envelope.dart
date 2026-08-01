import 'dart:convert';

const envKindTx = 'tx';
const envKindPresence = 'presence';
const envKindReceipt = 'receipt';
const envKindChat = 'chat';
const envKindPour = 'pour';
const meshInitialTtl = 8;

/// Wire envelope for the BLE gossip mesh (spec §2.1). Not independently
/// signed — `tx` payloads carry their own signature, re-validated on ingest.
class MeshEnvelope {
  const MeshEnvelope({
    required this.msgId,
    required this.kind,
    required this.origin,
    required this.target,
    required this.ttl,
    required this.path,
    required this.payload,
  });

  final String msgId; // UUIDv7, lowercase canonical — dedupe key
  final String kind;
  final String origin;
  final String? target; // null = broadcast/flood
  final int ttl;
  final List<String> path; // relay addresses; origin NOT included
  final String payload;

  /// Frame ready to (re)broadcast after this node relays it: ttl-1, self
  /// appended to path. Everything else carries over unchanged.
  MeshEnvelope relayedBy(String selfAddr) => MeshEnvelope(
    msgId: msgId,
    kind: kind,
    origin: origin,
    target: target,
    ttl: ttl - 1,
    path: [...path, selfAddr],
    payload: payload,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'msgId': msgId,
    'kind': kind,
    'origin': origin,
    'target': target,
    'ttl': ttl,
    'path': path,
    'payload': payload,
  };

  factory MeshEnvelope.fromJson(Map<String, Object?> json) {
    final v = json['v'],
        msgId = json['msgId'],
        kind = json['kind'],
        origin = json['origin'],
        target = json['target'],
        ttl = json['ttl'],
        path = json['path'],
        payload = json['payload'];
    if (v != 1 ||
        msgId is! String ||
        kind is! String ||
        origin is! String ||
        (target != null && target is! String) ||
        ttl is! int ||
        path is! List ||
        !path.every((e) => e is String) ||
        payload is! String) {
      throw const FormatException('malformed mesh envelope');
    }
    return MeshEnvelope(
      msgId: msgId,
      kind: kind,
      origin: origin,
      target: target as String?,
      ttl: ttl,
      path: List<String>.from(path),
      payload: payload,
    );
  }
}

class FrameDecodeException implements Exception {
  FrameDecodeException(this.message);
  final String message;
}

String encodeFrame(MeshEnvelope e) => jsonEncode(e.toJson());

MeshEnvelope decodeFrame(String frameJson) {
  final Object? json;
  try {
    json = jsonDecode(frameJson);
  } catch (_) {
    throw FrameDecodeException('malformed frame');
  }
  if (json is! Map<String, Object?>) {
    throw FrameDecodeException('malformed frame');
  }
  try {
    return MeshEnvelope.fromJson(json);
  } on FormatException {
    throw FrameDecodeException('malformed frame');
  }
}

String receiptPayload(String forMsgId, int hops) =>
    jsonEncode({'forMsgId': forMsgId, 'hops': hops});

(String forMsgId, int hops) parseReceiptPayload(String payload) {
  final Object? json;
  try {
    json = jsonDecode(payload);
  } catch (_) {
    throw const FormatException('malformed receipt payload');
  }
  if (json is! Map<String, Object?>) {
    throw const FormatException('malformed receipt payload');
  }
  final forMsgId = json['forMsgId'], hops = json['hops'];
  if (forMsgId is! String || hops is! int) {
    throw const FormatException('malformed receipt payload');
  }
  return (forMsgId, hops);
}

String presencePayload(String addr, String name) =>
    jsonEncode({'addr': addr, 'name': name});

({String addr, String name}) parsePresencePayload(String payload) {
  final Object? json;
  try {
    json = jsonDecode(payload);
  } catch (_) {
    throw const FormatException('malformed presence payload');
  }
  if (json is! Map<String, Object?>) {
    throw const FormatException('malformed presence payload');
  }
  final addr = json['addr'], name = json['name'];
  if (addr is! String || name is! String) {
    throw const FormatException('malformed presence payload');
  }
  return (addr: addr, name: name);
}
