import 'dart:async';
import '../ports/mesh_transport.dart';
import '../ports/notifier.dart';
import '../ports/outbox_store.dart';
import '../ports/seen_store.dart';

class FakeNotifier implements Notifier {
  final List<(int, String, String)> shown = [];
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id, title, body));
  }
}

class InMemoryOutboxStore implements OutboxStore {
  final Map<String, (String, DateTime)> _entries = {};
  @override
  Future<void> put(String msgId, String frameJson, DateTime expiresAt) async {
    _entries[msgId] = (frameJson, expiresAt);
  }

  @override
  Future<void> remove(String msgId) async => _entries.remove(msgId);
  @override
  Future<List<(String, String)>> pending() async =>
      _entries.entries.map((e) => (e.key, e.value.$1)).toList();
}

class InMemorySeenStore implements SeenStore {
  final Set<String> _seen = {};
  @override
  Future<Set<String>> load() async => Set.of(_seen);
  @override
  Future<void> add(String msgId) async => _seen.add(msgId);
}

/// Programmable fake transport. Records broadcasts into [sentFrames]; when
/// joined to a [LoopbackHub] its broadcasts also fan out to linked peers.
class FakeMeshTransport implements MeshTransport {
  bool running = false;
  final List<String> sentFrames = [];

  LoopbackHub? _hub;
  String? _hubAddr;

  final _peerEvents = StreamController<MeshPeer>.broadcast();
  final _inboundFrames = StreamController<String>.broadcast();

  @override
  Stream<MeshPeer> get peerEvents => _peerEvents.stream;
  @override
  Stream<String> get inboundFrames => _inboundFrames.stream;

  @override
  Future<void> start() async => running = true;
  @override
  Future<void> stop() async => running = false;

  @override
  Future<void> broadcastFrame(String frameJson) async {
    sentFrames.add(frameJson);
    final hub = _hub, addr = _hubAddr;
    if (hub != null && addr != null) hub._broadcastFrom(addr, frameJson);
  }

  /// Test-only: simulate a discovered/updated peer.
  void injectPeer(MeshPeer peer) => _peerEvents.add(peer);

  /// Test-only: simulate an inbound frame arriving off-hub.
  void injectFrame(String frameJson) => _inboundFrames.add(frameJson);

  void _attachHub(LoopbackHub hub, String addr) {
    _hub = hub;
    _hubAddr = addr;
  }

  void _deliverInbound(String frameJson) => _inboundFrames.add(frameJson);
  void _emitPeerEvent(MeshPeer peer) => _peerEvents.add(peer);
}

/// In-memory hub joining N [FakeMeshTransport]s into a virtual radio space —
/// the load-bearing multi-node test asset (spec §2.3). Joining creates a
/// full mesh by default; [setLink] partitions or reconnects specific pairs.
/// Frame delivery happens asynchronously (a later microtask via the
/// transport's non-sync broadcast stream), mirroring real radio latency.
class LoopbackHub {
  final Map<String, FakeMeshTransport> _transports = {};
  final Map<String, Set<String>> _links = {};

  void join(String addr, FakeMeshTransport t) {
    _transports[addr] = t;
    t._attachHub(this, addr);
    _links.putIfAbsent(addr, () => {});
    for (final other in _transports.keys.toList()) {
      if (other == addr) continue;
      _linkUp(addr, other);
    }
  }

  void setLink(String a, String b, {required bool up}) {
    if (up) {
      _linkUp(a, b);
    } else {
      _links[a]?.remove(b);
      _links[b]?.remove(a);
    }
  }

  void _linkUp(String a, String b) {
    final aLinks = _links.putIfAbsent(a, () => {});
    final bLinks = _links.putIfAbsent(b, () => {});
    final wasUp = aLinks.contains(b);
    aLinks.add(b);
    bLinks.add(a);
    if (!wasUp) {
      _notifyConnected(a, b);
      _notifyConnected(b, a);
    }
  }

  void _notifyConnected(String selfAddr, String peerAddr) {
    _transports[selfAddr]?._emitPeerEvent(
      MeshPeer(addr: peerAddr, name: null, rssi: -50, lastSeen: DateTime.now()),
    );
  }

  void _broadcastFrom(String fromAddr, String frameJson) {
    for (final peerAddr in _links[fromAddr] ?? const <String>{}) {
      _transports[peerAddr]?._deliverInbound(frameJson);
    }
  }
}
