import 'package:cash_me_outside/domain/canonical.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/features/history/history_screen.dart';
import 'package:cash_me_outside/features/send/mesh_send_flow.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Node {
  _Node(this.container, this.transport, this.addr);
  final ProviderContainer container;
  final FakeMeshTransport transport;
  final String addr;
}

Future<_Node> _createNode(
  List<ProviderContainer> registry,
  String name, {
  FakeMeshTransport? transport,
  FakeBiometricGate? gate,
}) async {
  final t = transport ?? FakeMeshTransport();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(meshTransport: t, gate: gate),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: name, avatar: '🦫');
  final keys = await container.read(walletKeysProvider.future);
  await container.read(meshControllerProvider.future); // build + subscribe
  return _Node(container, t, keys!.address);
}

/// Drains the async gossip chain (transport → engine → ledger → transport)
/// and lets pending provider state changes reach the widget tree. Multi-hop
/// round trips (send → ingest → receipt → delivered) cross several
/// microtask boundaries, mirroring the pattern A2's controller tests use.
Future<void> _flushMesh(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await pumpEventQueue();
    await tester.pump();
  }
}

Future<void> _pump(WidgetTester tester, ProviderContainer container, Widget child) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late List<ProviderContainer> containers;
  setUp(() => containers = []);
  tearDown(() {
    for (final c in containers) {
      c.dispose();
    }
  });

  testWidgets('empty state when no live peers', (tester) async {
    final sender = await _createNode(containers, 'Me');
    await _pump(tester, sender.container, const MeshSendFlow());
    expect(find.textContaining('No phones nearby'), findsOneWidget);
  });

  testWidgets(
    'unauthenticated peer name always paired with truncated address; '
    'unnamed peer falls back to truncated address alone',
    (tester) async {
      final sender = await _createNode(containers, 'Me');
      sender.transport.injectPeer(
        MeshPeer(addr: 'peerAddr', name: null, rssi: -50, lastSeen: DateTime.now()),
      );
      await _pump(tester, sender.container, const MeshSendFlow());
      expect(find.text(truncateAddr('peerAddr')), findsOneWidget);

      await sender.container.read(peerDirectoryProvider).record('peerAddr', 'Peery');
      // Re-pump to re-trigger the FutureBuilder's nameFor lookup.
      await _pump(tester, sender.container, const MeshSendFlow());
      expect(
        find.text('Peery · ${truncateAddr('peerAddr')}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('amount out of range: friendly error, stays on amount phase', (
    tester,
  ) async {
    final sender = await _createNode(containers, 'Me');
    sender.transport.injectPeer(
      MeshPeer(addr: 'peerAddr', name: 'Peery', rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(tester, sender.container, const MeshSendFlow());
    await tester.tap(find.byKey(const Key('mesh.peer.peerAddr')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mesh.send.amount')), '0');
    await tester.tap(find.byKey(const Key('mesh.send.confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining("not a real amount"), findsOneWidget);
    expect(find.byKey(const Key('mesh.send.amount')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('mesh.send.amount')),
      '${maxAmount + 1}',
    );
    await tester.tap(find.byKey(const Key('mesh.send.confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining("not a real amount"), findsOneWidget);
  });

  testWidgets('biometric denial: no send, stays on amount phase', (
    tester,
  ) async {
    final gate = FakeBiometricGate(approve: false);
    final sender = await _createNode(containers, 'Me', gate: gate);
    sender.transport.injectPeer(
      MeshPeer(addr: 'peerAddr', name: 'Peery', rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(tester, sender.container, const MeshSendFlow());
    await tester.tap(find.byKey(const Key('mesh.peer.peerAddr')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mesh.send.amount')), '10');
    await tester.tap(find.byKey(const Key('mesh.send.confirm')));
    await tester.pumpAndSettle();

    expect(gate.authCalls, 1);
    expect(find.text('Biometric check failed'), findsOneWidget);
    expect(find.byKey(const Key('mesh.send.amount')), findsOneWidget);
    final ledgerState = await sender.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.length, 1); // only the mint
  });

  testWidgets('empty memo becomes null on the signed transaction', (
    tester,
  ) async {
    final sender = await _createNode(containers, 'Me');
    sender.transport.injectPeer(
      MeshPeer(addr: 'peerAddr', name: 'Peery', rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(tester, sender.container, const MeshSendFlow());
    await tester.tap(find.byKey(const Key('mesh.peer.peerAddr')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mesh.send.amount')), '10');
    await tester.enterText(find.byKey(const Key('mesh.send.memo')), '   ');
    await tester.tap(find.byKey(const Key('mesh.send.confirm')));
    await tester.pumpAndSettle();

    final ledgerState = await sender.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.last.memo, isNull);
  });

  testWidgets(
    'peer picker → amount/memo → biometric → status hopping→delivered; '
    'History shows the matching delivery chip',
    (tester) async {
      final hub = LoopbackHub();
      final sender = await _createNode(containers, 'Me');
      final receiver = await _createNode(containers, 'Rex');
      hub.join(sender.addr, sender.transport);
      hub.join(receiver.addr, receiver.transport);
      await pumpEventQueue();
      await sender.container
          .read(peerDirectoryProvider)
          .record(receiver.addr, 'Rex');

      await _pump(tester, sender.container, const MeshSendFlow());
      expect(
        find.text('Rex · ${truncateAddr(receiver.addr)}'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(Key('mesh.peer.${receiver.addr}')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('mesh.send.amount')), '42');
      await tester.tap(find.byKey(const Key('mesh.send.confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hopping'), findsOneWidget);

      await _flushMesh(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Delivered'), findsOneWidget);

      final receiverState = await receiver.container.read(
        ledgerControllerProvider.future,
      );
      expect(receiverState.balances[receiver.addr], 542); // 500 mint + 42

      final senderLedger = await sender.container.read(
        ledgerControllerProvider.future,
      );
      final txId = senderLedger.ordered.last.id;

      await _pump(tester, sender.container, const HistoryScreen());
      expect(find.byKey(Key('mesh.status.$txId')), findsOneWidget);
      expect(find.textContaining('Delivered'), findsOneWidget);
    },
  );
}
