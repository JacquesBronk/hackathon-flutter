import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class _Node {
  _Node(
    this.container,
    this.transport,
    this.outboxStore,
    this.notifier,
    this.addr,
  );
  final ProviderContainer container;
  final FakeMeshTransport transport;
  final InMemoryOutboxStore outboxStore;
  final FakeNotifier notifier;
  final String addr;

  MeshController get mesh => container.read(meshControllerProvider.notifier);
}

Future<_Node> _createNode(List<ProviderContainer> registry, String name) async {
  final transport = FakeMeshTransport();
  final outboxStore = InMemoryOutboxStore();
  final notifier = FakeNotifier();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(
      meshTransport: transport,
      notifier: notifier,
      outboxStore: outboxStore,
    ),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: name, avatar: '🦫');
  final keys = await container.read(walletKeysProvider.future);
  await container.read(meshControllerProvider.future); // build + subscribe
  return _Node(container, transport, outboxStore, notifier, keys!.address);
}

void main() {
  late List<ProviderContainer> containers;

  setUp(() => containers = []);
  tearDown(() {
    for (final c in containers) {
      c.dispose();
    }
  });

  test('incoming tx envelope ingests, emits receipt, and notifies', () async {
    final node = await _createNode(containers, 'Jacques');
    final other = await WalletKeys.fromSeed(List.filled(32, 7));
    final tx = await buildSigned(
      keys: other,
      to: node.addr,
      amount: 42,
      type: txTypeTransfer,
      lamportTs: 1,
    );
    final envelope = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindTx,
      origin: other.address,
      target: node.addr,
      ttl: meshInitialTtl,
      path: const ['relay1'],
      payload: encodeTransaction(tx),
    );
    node.transport.injectFrame(encodeFrame(envelope));
    await pumpEventQueue();

    final state = await node.container.read(ledgerControllerProvider.future);
    expect(state.balances[node.addr], 542); // 500 mint + 42

    final receiptFrames = node.transport.sentFrames
        .map(decodeFrame)
        .where((e) => e.kind == envKindReceipt);
    expect(receiptFrames, hasLength(1));
    final receipt = receiptFrames.single;
    expect(receipt.target, other.address);
    expect(parseReceiptPayload(receipt.payload), (envelope.msgId, 1));
    expect(node.notifier.shown, isNotEmpty);
  });

  test('receipt updates delivery status to delivered', () async {
    final node = await _createNode(containers, 'Anna');
    final txId = await node.mesh.sendMeshTx(to: 'someone-else', amount: 10);
    await pumpEventQueue();

    final sentTxFrame = decodeFrame(node.transport.sentFrames.single);
    expect(sentTxFrame.kind, envKindTx);

    final receipt = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindReceipt,
      origin: 'someone-else',
      target: node.addr,
      ttl: meshInitialTtl,
      path: const [],
      payload: receiptPayload(sentTxFrame.msgId, 3),
    );
    node.transport.injectFrame(encodeFrame(receipt));
    await pumpEventQueue();

    final state = await node.container.read(meshControllerProvider.future);
    expect(state.deliveries[txId], MeshDeliveryStatus.delivered);
    expect(node.notifier.shown, isNotEmpty);
  });

  test(
    'targeted tx-kind envelope with garbage payload → no crash, no ledger change',
    () async {
      final node = await _createNode(containers, 'Garbage');
      final envelope = MeshEnvelope(
        msgId: _uuid.v7(),
        kind: envKindTx,
        origin: 'origin-addr',
        target: node.addr,
        ttl: meshInitialTtl,
        path: const [],
        payload: 'not a valid cmo:tx1: payload',
      );
      node.transport.injectFrame(encodeFrame(envelope));
      await pumpEventQueue();

      final state = await node.container.read(ledgerControllerProvider.future);
      expect(state.ordered, hasLength(1)); // only the mint, tx never ingested
      expect(
        node.transport.sentFrames
            .map(decodeFrame)
            .where((e) => e.kind == envKindReceipt),
        isEmpty,
      );
    },
  );

  test('presence envelope records the peer name', () async {
    final node = await _createNode(containers, 'Beto');
    final envelope = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindPresence,
      origin: 'peerAddr',
      target: null,
      ttl: meshInitialTtl,
      path: const [],
      payload: presencePayload('peerAddr', 'Peery'),
    );
    node.transport.injectFrame(encodeFrame(envelope));
    await pumpEventQueue();

    expect(
      await node.container.read(peerDirectoryProvider).nameFor('peerAddr'),
      'Peery',
    );
  });

  test('relaying a foreign tx envelope fires a relay notification', () async {
    final node = await _createNode(containers, 'Coco');
    final origin = await WalletKeys.fromSeed(List.filled(32, 3));
    final tx = await buildSigned(
      keys: origin,
      to: 'far-away-addr',
      amount: 99,
      type: txTypeTransfer,
      lamportTs: 1,
    );
    final envelope = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindTx,
      origin: origin.address,
      target: 'far-away-addr', // not this node
      ttl: meshInitialTtl,
      path: const [],
      payload: encodeTransaction(tx),
    );
    node.transport.injectFrame(encodeFrame(envelope));
    await pumpEventQueue();

    final relayed = node.transport.sentFrames
        .map(decodeFrame)
        .where((e) => e.kind == envKindTx && e.msgId == envelope.msgId);
    expect(relayed, hasLength(1));
    expect(relayed.single.path, [node.addr]);
    expect(
      node.notifier.shown.any((n) => n.$3.contains('relayed ᵽ99')),
      isTrue,
    );
  });

  test(
    'sendMeshTx with zero peers persists to outbox; peer connect flushes it',
    () async {
      final node = await _createNode(containers, 'Dara');
      await node.mesh.sendMeshTx(to: 'target-addr', amount: 15);
      await pumpEventQueue();

      expect(await node.outboxStore.pending(), hasLength(1));
      expect(node.transport.sentFrames, hasLength(1));

      node.transport.injectPeer(
        MeshPeer(
          addr: 'newpeer',
          name: null,
          rssi: -50,
          lastSeen: DateTime.now(),
        ),
      );
      await pumpEventQueue();

      expect(node.transport.sentFrames, hasLength(2));
      final first = decodeFrame(node.transport.sentFrames[0]);
      final second = decodeFrame(node.transport.sentFrames[1]);
      expect(second.msgId, first.msgId); // retransmit, unchanged frame
    },
  );

  test('peer-lost: link down empties livePeers; targeted send after disconnect '
      'parks in outbox; relink flushes and delivers', () async {
    final hub = LoopbackHub();
    final sender = await _createNode(containers, 'Sender');
    final receiver = await _createNode(containers, 'Receiver');
    hub.join(sender.addr, sender.transport);
    hub.join(receiver.addr, receiver.transport);
    await pumpEventQueue();

    final beforeState = await sender.container.read(
      meshControllerProvider.future,
    );
    expect(beforeState.livePeers.map((p) => p.addr), [receiver.addr]);

    hub.setLink(sender.addr, receiver.addr, up: false);
    await pumpEventQueue();

    final afterDisconnect = await sender.container.read(
      meshControllerProvider.future,
    );
    expect(afterDisconnect.livePeers, isEmpty);

    final txId = await sender.mesh.sendMeshTx(to: receiver.addr, amount: 33);
    await pumpEventQueue();
    expect(await sender.outboxStore.pending(), hasLength(1));
    final hoppingState = await sender.container.read(
      meshControllerProvider.future,
    );
    expect(hoppingState.deliveries[txId], MeshDeliveryStatus.hopping);

    hub.setLink(sender.addr, receiver.addr, up: true);
    await pumpEventQueue();
    await pumpEventQueue();
    await pumpEventQueue();

    final receiverState = await receiver.container.read(
      ledgerControllerProvider.future,
    );
    expect(receiverState.balances[receiver.addr], 533); // 500 mint + 33

    final deliveredState = await sender.container.read(
      meshControllerProvider.future,
    );
    expect(deliveredState.deliveries[txId], MeshDeliveryStatus.delivered);
    expect(await sender.outboxStore.pending(), isEmpty);
  });

  test(
    '4-node LoopbackHub chain sim: relay hops, exactly-once ingest, receipt hops',
    () async {
      final hub = LoopbackHub();
      final a = await _createNode(containers, 'A');
      final b = await _createNode(containers, 'B');
      final c = await _createNode(containers, 'C');
      final d = await _createNode(containers, 'D');

      hub.join(a.addr, a.transport);
      hub.join(b.addr, b.transport);
      hub.join(c.addr, c.transport);
      hub.join(d.addr, d.transport);
      // Only a chain stays up: a-b-c-d.
      hub.setLink(a.addr, c.addr, up: false);
      hub.setLink(a.addr, d.addr, up: false);
      hub.setLink(b.addr, d.addr, up: false);
      await pumpEventQueue();

      final txId = await a.mesh.sendMeshTx(to: d.addr, amount: 123);
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      final dState = await d.container.read(ledgerControllerProvider.future);
      expect(dState.balances[d.addr], 623); // 500 mint + 123
      expect(dState.ordered.where((t) => t.id == txId), hasLength(1));

      final aMesh = await a.container.read(meshControllerProvider.future);
      expect(aMesh.deliveries[txId], MeshDeliveryStatus.delivered);
      expect(
        a.notifier.shown.any((n) => n.$3.contains('via 2 phones')),
        isTrue,
      );
    },
  );

  test(
    'late-joining target receives store-and-forward via outbox flush',
    () async {
      final hub = LoopbackHub();
      final sender = await _createNode(containers, 'Sender');
      final target = await _createNode(containers, 'Target');

      // Sender is isolated (never joined) when it originates — this forces
      // the outbox path (spec §2.2 rule 5).
      final txId = await sender.mesh.sendMeshTx(to: target.addr, amount: 77);
      await pumpEventQueue();
      expect(await sender.outboxStore.pending(), hasLength(1));

      hub.join(sender.addr, sender.transport); // no peers yet — hub is empty
      await pumpEventQueue();
      expect(await sender.outboxStore.pending(), hasLength(1)); // unchanged

      hub.join(target.addr, target.transport); // late join triggers flush
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      final targetState = await target.container.read(
        ledgerControllerProvider.future,
      );
      expect(targetState.balances[target.addr], 577); // 500 mint + 77

      final senderMesh = await sender.container.read(
        meshControllerProvider.future,
      );
      expect(senderMesh.deliveries[txId], MeshDeliveryStatus.delivered);
      expect(await sender.outboxStore.pending(), isEmpty); // cleared on receipt
    },
  );
}
