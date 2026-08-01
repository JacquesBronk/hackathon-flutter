import 'dart:async';

import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:cash_me_outside/features/pour/catch_screen.dart';
import 'package:cash_me_outside/features/pour/pour_screen.dart';
import 'package:cash_me_outside/features/rain/rain_screen.dart';
import 'package:cash_me_outside/features/send/send_flow.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:cash_me_outside/state/grace_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// B5 integration e2e: pour/rain/shake-cancel money invariants across real
/// mesh delivery (LoopbackHub), per the plan's Task B5 checklist. B1-B4's
/// own tests exercise these controllers/widgets in isolation (single
/// container, envelopes injected directly); this file is the only coverage
/// of the actual cross-device mesh path these features rely on in
/// production — the gap B5's real routes/providers wiring closes.
class _Node {
  _Node(this.container, this.transport, this.addr);
  final ProviderContainer container;
  final FakeMeshTransport transport;
  final String addr;
}

Future<_Node> _createNode(
  List<ProviderContainer> registry,
  String name, {
  FakeMotionSensor? motionSensor,
  FakeBiometricGate? gate,
}) async {
  final transport = FakeMeshTransport();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(
      meshTransport: transport,
      motionSensor: motionSensor,
      gate: gate,
    ),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: name, avatar: '🦫');
  final keys = await container.read(walletKeysProvider.future);
  // Build + subscribe BEFORE the hub joins it — hub.join() emits peerEvents
  // synchronously and broadcast StreamControllers don't replay to late
  // subscribers (see test/integration/mesh_e2e_test.dart's pattern).
  await container.read(meshControllerProvider.future);
  await container.read(pourControllerProvider.future);
  return _Node(container, transport, keys!.address);
}

/// Drains the async gossip chain (transport -> engine -> ledger -> transport)
/// across several microtask boundaries — plain tester.pump() rather than
/// pumpEventQueue() (which hangs forever inside testWidgets).
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
    'radial menu: Pour and Rain are enabled, routing to the peer picker and '
    'the rain screen; other still-unimplemented methods stay disabled',
    (tester) async {
      final transport = FakeMeshTransport();
      final container = ProviderContainer(
        overrides: fakeHardwareOverrides(meshTransport: transport),
      );
      addTearDown(container.dispose);
      // NOTE: overrides live on the CONTAINER only — CashMeOutsideApp's own
      // inner ProviderScope must stay override-free (see
      // test/integration/two_party_flow_test.dart for why).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CashMeOutsideApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('onboard.name')), 'Jax');
      await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
      await tester.tap(find.byKey(const Key('onboard.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.mint.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.biometric')));
      await tester.pumpAndSettle();

      // Build + subscribe BEFORE injecting the peer — broadcast
      // StreamControllers don't replay to late subscribers, so the mesh
      // controller must already be listening (see mesh_e2e_test.dart).
      await container.read(meshControllerProvider.future);

      final peer = await WalletKeys.fromSeed(List.filled(32, 3));
      transport.injectPeer(
        MeshPeer(
          addr: peer.address,
          name: 'Nia',
          rssi: -40,
          lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('wallet.send')));
      await tester.pumpAndSettle();
      // Graph C's NFC entry (and the other still-unbuilt methods) must stay
      // untouched — only Pour/Rain flip from disabled to enabled here.
      expect(find.textContaining('NFC'), findsOneWidget);
      expect(find.byKey(const Key('send.method.pour')), findsOneWidget);
      expect(find.byKey(const Key('send.method.rain')), findsOneWidget);

      await tester.tap(find.byKey(const Key('send.method.pour')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('pour.peer.${peer.address}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pour.start')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wallet.send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send.method.rain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rain.amount')), findsOneWidget);
    },
  );

  testWidgets(
    'pour 25 via mesh to a catch screen: cup fills, final tx ingests, '
    'balance moves exactly 25',
    (tester) async {
      final hub = LoopbackHub();
      final motion = FakeMotionSensor();
      final sender = await _createNode(
        containers,
        'Pourer',
        motionSensor: motion,
      );
      final receiver = await _createNode(containers, 'Catcher');
      hub.join(sender.addr, sender.transport);
      hub.join(receiver.addr, receiver.transport);

      final ticker = StreamController<void>.broadcast();
      addTearDown(ticker.close);
      // Instant grace window: no real Timer, so the test never has to
      // advance the fake clock — deterministic per the LESSONS constraint
      // (see pour_test.dart's own rig for the same workaround).
      final instantGrace = GraceWindow(scheduler: (_) async {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: sender.container,
          child: MaterialApp(
            home: PourScreen(
              to: receiver.addr,
              ticker: ticker.stream,
              graceWindow: instantGrace,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pour.start')));
      await tester.pump();
      motion.emitTilt(10); // full tilt -> max rate, 25 pinnies/sec
      await tester.pump();
      // 4 ticks * 250ms * 25/sec = exactly 25 pinnies (PourAccumulator's
      // exact running total avoids per-tick floor loss).
      for (var i = 0; i < 4; i++) {
        ticker.add(null);
        await tester.pump();
      }
      final poured = sender.container
          .read(pourControllerProvider)
          .value!
          .outgoing!
          .pouredTotal;
      expect(poured, 25);

      await tester.tap(find.byKey(const Key('pour.stop')));
      await tester.pump();
      // Drains the real (fake-clock-backed) grace window, biometric gate,
      // and finishPour's single signed tx — see send_test.dart for the
      // same pattern with the QR flow's grace window.
      await tester.pumpAndSettle();
      await _flushMesh(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pour.done')), findsOneWidget);

      // Catch side: pour envelopes crossed the mesh and folded into the
      // receiver's own PourController + rendered cup.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: receiver.container,
          child: const MaterialApp(home: CatchScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final catchState = receiver.container
          .read(pourControllerProvider)
          .value!
          .catchState!;
      expect(catchState.pouredTotal, 25);
      expect(catchState.state, pourStateFinal);
      expect(find.textContaining('25'), findsWidgets);

      // Money invariant: the receiver ingested EXACTLY one signed tx for
      // the poured total, via the ordinary tx mesh path (never the
      // cosmetic pour envelopes themselves).
      final receiverLedger = await receiver.container.read(
        ledgerControllerProvider.future,
      );
      expect(receiverLedger.balances[receiver.addr], 525); // 500 mint + 25
      expect(receiverLedger.ordered.where((t) => t.amount == 25), hasLength(1));
    },
  );

  testWidgets(
    'rain across 3 mesh peers: each receives their exact share off one '
    'biometric call, shares sum to the total',
    (tester) async {
      final hub = LoopbackHub();
      final gate = FakeBiometricGate();
      final sender = await _createNode(containers, 'Rainer', gate: gate);
      final r1 = await _createNode(containers, 'Ann');
      final r2 = await _createNode(containers, 'Bo');
      final r3 = await _createNode(containers, 'Cy');
      hub.join(sender.addr, sender.transport);
      hub.join(r1.addr, r1.transport);
      hub.join(r2.addr, r2.transport);
      hub.join(r3.addr, r3.transport);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: sender.container,
          child: const MaterialApp(home: RainScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 phones nearby'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('rain.amount')), '30');
      await tester.tap(find.byKey(const Key('rain.trigger')));
      await tester.pumpAndSettle();
      await _flushMesh(tester);
      await tester.pumpAndSettle();

      expect(gate.authCalls, 1); // one biometric prompt for the whole burst

      var total = 0;
      for (final r in [r1, r2, r3]) {
        final ledger = await r.container.read(ledgerControllerProvider.future);
        final share = ledger.balances[r.addr]! - 500; // 500 mint baseline
        expect(share, greaterThanOrEqualTo(1)); // every share >= 1
        expect(ledger.ordered.where((t) => t.amount == share), hasLength(1));
        total += share;
      }
      expect(total, 30); // shares sum exactly to the rained total
    },
  );

  testWidgets(
    'shake-to-cancel in the QR send confirm flow: grace aborts before '
    'signing, ledger stays untouched',
    (tester) async {
      final scanner = FakeQrScanner();
      final motion = FakeMotionSensor();
      final container = ProviderContainer(
        overrides: fakeHardwareOverrides(
          scanner: scanner,
          motionSensor: motion,
        ),
      );
      addTearDown(container.dispose);
      await container
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Me', avatar: '🦫');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SendFlow()),
        ),
      );
      await tester.pumpAndSettle();

      final peer = await WalletKeys.fromSeed(List.filled(32, 9));
      scanner.emit(
        encodeReceiveRequest(
          ReceiveRequest(addr: peer.address, name: 'Anna', amount: 40),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('send.confirm')));
      await tester.pump(); // biometric approves -> phase becomes grace
      await tester.pump();
      expect(find.text('Sending… shake to cancel'), findsOneWidget);

      motion.emitShake();
      await tester.pump();
      await tester.pumpAndSettle();
      // The underlying GraceWindow scheduler's real Future.delayed(5s) timer
      // keeps running even after an early abort (only the completer settles
      // early) — drain it before teardown, matching
      // grace_window_widget_test.dart's "cancel button" test.
      await tester.pump(const Duration(seconds: 5));

      // Aborted before any sign — back on confirm, no QR code screen ever
      // shown, and the ledger has ONLY the onboarding mint (money invariant:
      // shake-cancel must abort strictly before send()/finishPour()'s
      // sign+ingest, never after).
      expect(find.byKey(const Key('send.confirm')), findsOneWidget);
      final state = await container.read(ledgerControllerProvider.future);
      expect(state.ordered.length, 1);
      expect(state.balances[peer.address], isNull);
    },
  );
}
