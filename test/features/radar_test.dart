import 'dart:async';
import 'dart:math' as math;

import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/mesh/gossip_engine.dart';
import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/features/radar/radar_screen.dart';
import 'package:cash_me_outside/features/send/mesh_send_flow.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:flutter_test/flutter_test.dart';

class _RecordingObserver extends NavigatorObserver {
  final pushed = <Object?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.arguments);
  }
}

Future<(ProviderContainer, FakeMeshTransport)> _pumpRadar(
  WidgetTester tester, {
  Stream<RelayEvent>? relayEvents,
  Stream<double>? headings,
  NavigatorObserver? observer,
}) async {
  final transport = FakeMeshTransport();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(meshTransport: transport),
  );
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Me', avatar: '🦫');
  // Ensure the controller has built (and subscribed to the transport) before
  // tests start injecting peer events.
  await container.read(meshControllerProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorObservers: observer == null ? const [] : [observer],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => settings.name == '/send-mesh'
              ? MeshSendFlow(initialPeerAddr: settings.arguments as String?)
              : const SizedBox(),
          settings: settings,
        ),
        home: RadarScreen(relayEvents: relayEvents, headings: headings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, transport);
}

MeshPeer _peer(String addr, int rssi) => MeshPeer(
  addr: addr,
  name: null,
  rssi: rssi,
  lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  testWidgets('renders one blip per live peer, keyed by address', (
    tester,
  ) async {
    final (_, transport) = await _pumpRadar(tester);
    final near = await WalletKeys.fromSeed(List.filled(32, 1));
    final mid = await WalletKeys.fromSeed(List.filled(32, 2));
    final far = await WalletKeys.fromSeed(List.filled(32, 3));

    transport.injectPeer(_peer(near.address, -40)); // inner ring
    transport.injectPeer(_peer(mid.address, -70)); // mid ring
    transport.injectPeer(_peer(far.address, -90)); // outer ring
    await tester.pump();
    await tester.pump();

    expect(find.byKey(Key('radar.blip.${near.address}')), findsOneWidget);
    expect(find.byKey(Key('radar.blip.${mid.address}')), findsOneWidget);
    expect(find.byKey(Key('radar.blip.${far.address}')), findsOneWidget);
  });

  testWidgets('unauthenticated peer name always shown with truncated address', (
    tester,
  ) async {
    final (_, transport) = await _pumpRadar(tester);
    final peer = await WalletKeys.fromSeed(List.filled(32, 4));
    transport.injectPeer(
      MeshPeer(
        addr: peer.address,
        name: 'Anna',
        rssi: -40,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Anna'), findsOneWidget);
    expect(find.textContaining(truncateAddr(peer.address)), findsOneWidget);
  });

  testWidgets('tapping a blip navigates to /send-mesh with the peer address', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    final (_, transport) = await _pumpRadar(tester, observer: observer);
    final peer = await WalletKeys.fromSeed(List.filled(32, 5));
    transport.injectPeer(_peer(peer.address, -40));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(Key('radar.blip.${peer.address}')));
    await tester.pumpAndSettle();

    expect(observer.pushed, contains(peer.address));
    // The tapped blip's addr reaches MeshSendFlow, which prefills straight
    // to the amount phase for that peer (spec §2.4).
    expect(find.byKey(const Key('mesh.send.amount')), findsOneWidget);
    expect(find.textContaining(truncateAddr(peer.address)), findsOneWidget);
  });

  testWidgets('relay event triggers a single-run pulse, never loops', (
    tester,
  ) async {
    final relayController = StreamController<RelayEvent>.broadcast();
    addTearDown(relayController.close);
    await _pumpRadar(tester, relayEvents: relayController.stream);

    relayController.add(
      RelayEvent(
        envelope: MeshEnvelope(
          msgId: 'm1',
          kind: envKindTx,
          origin: 'origin-addr',
          target: 'target-addr',
          ttl: 7,
          path: const [],
          payload: 'irrelevant',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Finite animation: pumpAndSettle must terminate. A looping controller
    // would hang this call.
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: blips render statically, no pulse triggered', (
    tester,
  ) async {
    final relayController = StreamController<RelayEvent>.broadcast();
    addTearDown(relayController.close);
    final transport = FakeMeshTransport();
    final container = ProviderContainer(
      overrides: fakeHardwareOverrides(meshTransport: transport),
    );
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    await container.read(meshControllerProvider.future);
    final peer = await WalletKeys.fromSeed(List.filled(32, 6));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => const SizedBox(),
              settings: settings,
            ),
            home: RadarScreen(relayEvents: relayController.stream),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    transport.injectPeer(_peer(peer.address, -40));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(Key('radar.blip.${peer.address}')), findsOneWidget);

    relayController.add(
      RelayEvent(
        envelope: MeshEnvelope(
          msgId: 'm2',
          kind: envKindTx,
          origin: 'o',
          target: 't',
          ttl: 7,
          path: const [],
          payload: 'x',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(Key('radar.blip.${peer.address}')), findsOneWidget);
  });

  testWidgets(
    'compass heading rotates blip position (B5 bearing merge); absent '
    'heading data leaves the RSSI-ring-only layout unchanged',
    (tester) async {
      final headings = StreamController<double>.broadcast();
      addTearDown(headings.close);
      final (_, transport) = await _pumpRadar(
        tester,
        headings: headings.stream,
      );
      final peer = await WalletKeys.fromSeed(List.filled(32, 7));
      transport.injectPeer(_peer(peer.address, -40));
      await tester.pump();
      await tester.pump();

      // No heading reading has arrived yet — same fallback layout as every
      // other test in this file (which never passes `headings` at all).
      final beforeHeading = tester.getCenter(
        find.byKey(Key('radar.blip.${peer.address}')),
      );

      headings.add(math.pi / 2);
      await tester.pump();
      await tester.pump();

      final afterHeading = tester.getCenter(
        find.byKey(Key('radar.blip.${peer.address}')),
      );
      expect(afterHeading, isNot(equals(beforeHeading)));
    },
  );
}
