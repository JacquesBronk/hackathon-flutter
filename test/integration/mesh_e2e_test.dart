import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HeadlessNode {
  _HeadlessNode(this.container, this.transport, this.notifier, this.addr);
  final ProviderContainer container;
  final FakeMeshTransport transport;
  final FakeNotifier notifier;
  final String addr;
}

Future<_HeadlessNode> _createHeadlessNode(
  List<ProviderContainer> registry,
  String name,
) async {
  final transport = FakeMeshTransport();
  final notifier = FakeNotifier();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(
      meshTransport: transport,
      notifier: notifier,
    ),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: name, avatar: '🦫');
  final keys = await container.read(walletKeysProvider.future);
  // Build + subscribe BEFORE the hub joins it below — hub.join() emits
  // peerEvents synchronously and broadcast StreamControllers don't replay
  // to late subscribers (see test/state/mesh_controller_test.dart pattern).
  await container.read(meshControllerProvider.future);
  return _HeadlessNode(container, transport, notifier, keys!.address);
}

/// Drains the async gossip chain (transport -> engine -> ledger -> transport)
/// across several microtask boundaries. NOTE: `pumpEventQueue()` hangs
/// forever inside `testWidgets` (Flutter's fake-clock test binding never
/// fires the real `Future.delayed` it loops on) — plain `tester.pump()`
/// correctly drains the microtask queue broadcast StreamControllers use.
Future<void> _flushMesh(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  late List<ProviderContainer> containers;
  setUp(() => containers = []);
  tearDown(() {
    for (final c in containers) {
      c.dispose();
    }
  });

  testWidgets(
    'full e2e: onboard -> radial -> Mesh -> pick live peer -> biometric -> '
    'hopping -> delivered with hop count; radar shows the peer; a relaying '
    'bystander fires its own relay notification',
    (tester) async {
      final hub = LoopbackHub();
      final receiver = await _createHeadlessNode(containers, 'Rex');
      final bystander = await _createHeadlessNode(containers, 'Bea');

      final senderTransport = FakeMeshTransport();
      final senderNotifier = FakeNotifier();
      final senderContainer = ProviderContainer(
        overrides: fakeHardwareOverrides(
          meshTransport: senderTransport,
          notifier: senderNotifier,
        ),
      );
      containers.add(senderContainer);

      // NOTE: overrides live on the CONTAINER only — CashMeOutsideApp's own
      // inner ProviderScope must stay override-free here (see
      // test/integration/two_party_flow_test.dart for why).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: senderContainer,
          child: const CashMeOutsideApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Onboard the sender through the real production UI.
      await tester.enterText(find.byKey(const Key('onboard.name')), 'Jacques');
      await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
      await tester.tap(find.byKey(const Key('onboard.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.mint.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.biometric')));
      await tester.pumpAndSettle();

      final senderAddr =
          (await senderContainer.read(walletKeysProvider.future))!.address;
      await senderContainer.read(meshControllerProvider.future);

      // Star topology: sender is directly linked to both Receiver and
      // Bystander; Receiver and Bystander are NOT linked to each other.
      // A tx targeted at Receiver still reaches Bystander too (sender
      // broadcasts to all its links) — Bystander relays it for a
      // "stranger" (exercising the relay-notification path) while Receiver
      // (the actual target) delivers it directly, hop count 0.
      hub.join(senderAddr, senderTransport);
      hub.join(receiver.addr, receiver.transport);
      hub.join(bystander.addr, bystander.transport);
      hub.setLink(receiver.addr, bystander.addr, up: false);
      await _flushMesh(tester);

      await senderContainer
          .read(peerDirectoryProvider)
          .record(receiver.addr, 'Rex');

      // Radial menu -> Mesh is enabled and routes to the mesh send flow.
      await tester.tap(find.byKey(const Key('wallet.send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send.method.mesh')), findsOneWidget);
      await tester.tap(find.byKey(const Key('send.method.mesh')));
      await tester.pumpAndSettle();

      // Peer picker shows both live peers; pick Receiver specifically.
      expect(
        find.text('Rex · ${truncateAddr(receiver.addr)}'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('mesh.peer.${bystander.addr}')),
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

      // Receiver's stack ingested the transaction exactly once.
      final receiverLedger = await receiver.container.read(
        ledgerControllerProvider.future,
      );
      expect(receiverLedger.balances[receiver.addr], 542); // 500 mint + 42

      // Receipt hop count reaches the sender (direct link -> 0 hops).
      expect(
        senderNotifier.shown.any(
          (n) => n.$2 == 'Delivered' && n.$3.contains('arrived via 0 phones'),
        ),
        isTrue,
      );
      expect(
        receiver.notifier.shown.any((n) => n.$2 == 'Pinnies received'),
        isTrue,
      );

      // Bystander overheard the tx (not addressed to it) and relayed it —
      // the relay-notification path, fired on Bystander's own notifier.
      expect(
        bystander.notifier.shown.any(
          (n) => n.$3.contains('relayed ᵽ42 for a stranger'),
        ),
        isTrue,
      );

      // Radar (real route wiring via app.dart) shows the peer we just sent
      // to as a live blip.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wallet.radar')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('radar.blip.${receiver.addr}')), findsOneWidget);
    },
  );
}
