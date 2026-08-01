import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:cash_me_outside/features/rain/rain_screen.dart';
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
  List<ProviderContainer> registry, {
  FakeBiometricGate? gate,
  FakeMotionSensor? motionSensor,
  FakeHaptics? haptics,
}) async {
  final transport = FakeMeshTransport();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(
      meshTransport: transport,
      gate: gate,
      motionSensor: motionSensor,
      haptics: haptics,
    ),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Rainmaker', avatar: '🌧️');
  await container.read(meshControllerProvider.future);
  await container.read(rainControllerProvider.future);
  final keys = await container.read(walletKeysProvider.future);
  return _Node(container, transport, keys!.address);
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: MaterialApp(home: child),
      ),
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
    final node = await _createNode(containers);
    await _pump(tester, node.container, const RainScreen());
    expect(find.textContaining('No phones nearby'), findsOneWidget);
    expect(find.byKey(const Key('rain.amount')), findsNothing);
  });

  testWidgets(
    'button trigger with 3 live peers: 3 sends, shares sum, per-recipient '
    'text shown',
    (tester) async {
      final node = await _createNode(containers);
      for (var i = 1; i <= 3; i++) {
        node.transport.injectPeer(
          MeshPeer(
            addr: 'peer$i',
            name: null,
            rssi: -50,
            lastSeen: DateTime.now(),
          ),
        );
      }
      await _pump(tester, node.container, const RainScreen());
      expect(find.textContaining('3 phones'), findsOneWidget);
      expect(find.byKey(const Key('rain.shake.hint')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('rain.amount')), '30');
      await tester.tap(find.byKey(const Key('rain.trigger')));
      await tester.pumpAndSettle();

      final ledgerState = await node.container.read(
        ledgerControllerProvider.future,
      );
      final transfers = ledgerState.ordered
          .where((t) => t.type == 'transfer')
          .toList();
      expect(transfers.length, 3);
      expect(transfers.map((t) => t.amount).reduce((a, b) => a + b), 30);
      expect(transfers.every((t) => t.amount >= 1), isTrue);

      for (var i = 1; i <= 3; i++) {
        expect(find.byKey(Key('rain.sent.peer$i')), findsOneWidget);
      }
    },
  );

  testWidgets('shake triggers the same send as the button', (tester) async {
    final motionSensor = FakeMotionSensor();
    final node = await _createNode(containers, motionSensor: motionSensor);
    node.transport.injectPeer(
      MeshPeer(addr: 'peerA', name: null, rssi: -50, lastSeen: DateTime.now()),
    );
    node.transport.injectPeer(
      MeshPeer(addr: 'peerB', name: null, rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(tester, node.container, const RainScreen());

    await tester.enterText(find.byKey(const Key('rain.amount')), '10');
    motionSensor.emitShake();
    await tester.pumpAndSettle();

    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.where((t) => t.type == 'transfer').length, 2);
  });

  testWidgets('amount below peer count: friendly error, no send', (
    tester,
  ) async {
    final node = await _createNode(containers);
    for (var i = 1; i <= 3; i++) {
      node.transport.injectPeer(
        MeshPeer(
          addr: 'peer$i',
          name: null,
          rssi: -50,
          lastSeen: DateTime.now(),
        ),
      );
    }
    await _pump(tester, node.container, const RainScreen());

    await tester.enterText(find.byKey(const Key('rain.amount')), '2');
    await tester.tap(find.byKey(const Key('rain.trigger')));
    await tester.pumpAndSettle();

    expect(find.textContaining("enough pinnies"), findsOneWidget);
    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.where((t) => t.type == 'transfer'), isEmpty);
  });

  testWidgets('biometric denial: no send, stays on entry', (tester) async {
    final gate = FakeBiometricGate(approve: false);
    final node = await _createNode(containers, gate: gate);
    node.transport.injectPeer(
      MeshPeer(addr: 'peerA', name: null, rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(tester, node.container, const RainScreen());

    await tester.enterText(find.byKey(const Key('rain.amount')), '5');
    await tester.tap(find.byKey(const Key('rain.trigger')));
    await tester.pumpAndSettle();

    expect(gate.authCalls, 1);
    expect(find.byKey(const Key('rain.amount')), findsOneWidget);
    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.where((t) => t.type == 'transfer'), isEmpty);
  });

  testWidgets('reduced motion: button fallback still sends, no looping '
      'animation to hang pumpAndSettle', (tester) async {
    final node = await _createNode(containers);
    node.transport.injectPeer(
      MeshPeer(addr: 'peerA', name: null, rssi: -50, lastSeen: DateTime.now()),
    );
    await _pump(
      tester,
      node.container,
      const RainScreen(),
      reducedMotion: true,
    );

    await tester.enterText(find.byKey(const Key('rain.amount')), '8');
    await tester.tap(find.byKey(const Key('rain.trigger')));
    await tester.pumpAndSettle();

    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered.where((t) => t.type == 'transfer').length, 1);
  });
}
