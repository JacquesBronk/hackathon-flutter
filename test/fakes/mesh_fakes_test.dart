import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/ports/mesh_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeNotifier records shown notifications', () async {
    final n = FakeNotifier();
    await n.show(id: 1, title: 't', body: 'b');
    expect(n.shown, [(1, 't', 'b')]);
  });

  test('InMemoryOutboxStore put/remove/pending round trip', () async {
    final store = InMemoryOutboxStore();
    final exp = DateTime(2026, 1, 1);
    await store.put('m1', 'frame1', exp);
    expect(await store.pending(), [('m1', 'frame1')]);
    await store.remove('m1');
    expect(await store.pending(), isEmpty);
  });

  test('InMemorySeenStore load/add round trip', () async {
    final store = InMemorySeenStore();
    expect(await store.load(), isEmpty);
    await store.add('a');
    await store.add('b');
    expect(await store.load(), {'a', 'b'});
  });

  test('FakeMeshTransport records broadcasts and supports injection', () async {
    final t = FakeMeshTransport();
    expect(t.running, isFalse);
    await t.start();
    expect(t.running, isTrue);
    await t.broadcastFrame('frame1');
    expect(t.sentFrames, ['frame1']);

    final peers = <MeshPeer>[];
    final sub1 = t.peerEvents.listen(peers.add);
    t.injectPeer(
      MeshPeer(addr: 'x', name: 'X', rssi: -40, lastSeen: DateTime.now()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(peers.single.addr, 'x');
    await sub1.cancel();

    final frames = <String>[];
    final sub2 = t.inboundFrames.listen(frames.add);
    t.injectFrame('inbound1');
    await Future<void>.delayed(Duration.zero);
    expect(frames, ['inbound1']);
    await sub2.cancel();
  });

  test(
    'LoopbackHub delivers broadcasts between two joined transports',
    () async {
      final hub = LoopbackHub();
      final a = FakeMeshTransport();
      final b = FakeMeshTransport();
      hub.join('a', a);
      hub.join('b', b);

      final bFrames = <String>[];
      final sub = b.inboundFrames.listen(bFrames.add);
      await a.broadcastFrame('hello');
      await pumpEventQueue();
      expect(bFrames, ['hello']);
      await sub.cancel();
    },
  );

  test('LoopbackHub join emits connect peer events on both sides', () async {
    final hub = LoopbackHub();
    final a = FakeMeshTransport();
    final b = FakeMeshTransport();
    final aPeers = <MeshPeer>[];
    final bPeers = <MeshPeer>[];
    final subA = a.peerEvents.listen(aPeers.add);
    final subB = b.peerEvents.listen(bPeers.add);

    hub.join('a', a);
    hub.join('b', b);
    await pumpEventQueue();

    expect(aPeers.map((p) => p.addr), contains('b'));
    expect(bPeers.map((p) => p.addr), contains('a'));
    await subA.cancel();
    await subB.cancel();
  });

  test('LoopbackHub setLink(up: false) partitions a pair', () async {
    final hub = LoopbackHub();
    final a = FakeMeshTransport();
    final b = FakeMeshTransport();
    final c = FakeMeshTransport();
    hub.join('a', a);
    hub.join('b', b);
    hub.join('c', c);
    hub.setLink('a', 'c', up: false);

    final bFrames = <String>[];
    final cFrames = <String>[];
    final subB = b.inboundFrames.listen(bFrames.add);
    final subC = c.inboundFrames.listen(cFrames.add);

    await a.broadcastFrame('flood');
    await pumpEventQueue();
    expect(bFrames, ['flood']); // a-b still up
    expect(cFrames, isEmpty); // a-c partitioned

    hub.setLink('a', 'c', up: true);
    await a.broadcastFrame('flood2');
    await pumpEventQueue();
    expect(cFrames, ['flood2']); // reconnected

    await subB.cancel();
    await subC.cancel();
  });

  test(
    'LoopbackHub setLink(up: false) emits peerLost to both sides exactly once',
    () async {
      final hub = LoopbackHub();
      final a = FakeMeshTransport();
      final b = FakeMeshTransport();
      hub.join('a', a);
      hub.join('b', b);

      final aLost = <String>[];
      final bLost = <String>[];
      final subA = a.peerLost.listen(aLost.add);
      final subB = b.peerLost.listen(bLost.add);

      hub.setLink('a', 'b', up: false);
      await pumpEventQueue();
      expect(aLost, ['b']);
      expect(bLost, ['a']);

      // Already down — setLink(up:false) again must not re-emit.
      hub.setLink('a', 'b', up: false);
      await pumpEventQueue();
      expect(aLost, ['b']);
      expect(bLost, ['a']);

      await subA.cancel();
      await subB.cancel();
    },
  );
}
