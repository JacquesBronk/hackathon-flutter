import 'dart:async';

import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:cash_me_outside/features/pour/pour_screen.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:cash_me_outside/state/grace_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rig {
  _Rig({
    required this.container,
    required this.motion,
    required this.haptics,
    required this.transport,
    required this.gate,
  });
  final ProviderContainer container;
  final FakeMotionSensor motion;
  final FakeHaptics haptics;
  final FakeMeshTransport transport;
  final FakeBiometricGate gate;
}

// Provider wiring is done directly in each test body (not in setUp()) — a
// package:test setUp() callback runs its async chain in a way that leaves
// Riverpod's Flutter-vsync-batched state notifications unflushed across
// plain tester.pump() calls, so widgets built from a setUp()-built container
// can hang waiting on controller state that never settles. Matches
// mesh_send_test.dart's _createNode / receive_test.dart's inline pattern.
Future<_Rig> _buildRig(
  WidgetTester tester, {
  bool approveBiometrics = true,
}) async {
  final motion = FakeMotionSensor();
  final haptics = FakeHaptics();
  final transport = FakeMeshTransport();
  final gate = FakeBiometricGate(approve: approveBiometrics);
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(
      motionSensor: motion,
      haptics: haptics,
      meshTransport: transport,
      gate: gate,
    ),
  );
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Pourer', avatar: '🦫');
  await container.read(walletKeysProvider.future);
  await container.read(meshControllerProvider.future);
  await container.read(pourControllerProvider.future);
  return _Rig(
    container: container,
    motion: motion,
    haptics: haptics,
    transport: transport,
    gate: gate,
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
  // pumpAndSettle (not a bare pump()) so the zero-duration Timer Riverpod
  // schedules from createWallet()'s ref.invalidate(walletKeysProvider) (see
  // _buildRig) actually elapses instead of tripping flutter_test's "Timer
  // still pending" invariant at teardown.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unauthenticated peer name is always paired with the truncated address '
    '(money-moving screen — spec §3 name-display rule)',
    (tester) async {
      final rig = await _buildRig(tester);

      await _pump(
        tester,
        rig.container,
        const PourScreen(to: 'receiver-addr', toName: 'Anna'),
      );

      expect(
        find.text('Anna · ${truncateAddr('receiver-addr')}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tilt pours pinnies, amount updates, stop → grace elapses → biometric → '
    'exactly one signed tx for the poured total',
    (tester) async {
      final rig = await _buildRig(tester);
      final ticker = StreamController<void>.broadcast();
      addTearDown(ticker.close);
      // Instant grace window: no real Timer, so the test never has to
      // advance the fake clock — deterministic per the LESSONS constraint.
      final instantGrace = GraceWindow(scheduler: (_) async {});

      await _pump(
        tester,
        rig.container,
        PourScreen(
          to: 'receiver-addr',
          ticker: ticker.stream,
          graceWindow: instantGrace,
        ),
      );

      await tester.tap(find.byKey(const Key('pour.start')));
      await tester.pump();

      rig.motion.emitTilt(10); // full tilt
      await tester.pump();
      ticker.add(null);
      await tester.pump();
      ticker.add(null);
      await tester.pump();

      final poured = rig.container
          .read(pourControllerProvider)
          .value!
          .outgoing!
          .pouredTotal;
      expect(poured, greaterThan(0));
      expect(find.text('ᵽ$poured'), findsOneWidget);
      expect(rig.haptics.tickCount, poured);

      await tester.tap(find.byKey(const Key('pour.stop')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(rig.gate.authCalls, 1);
      final frames = rig.transport.sentFrames.map(decodeFrame).toList();
      final txFrames = frames.where((e) => e.kind == envKindTx).toList();
      expect(txFrames, hasLength(1)); // exactly one signed tx
      final finalFrame = parsePourPayload(
        frames.lastWhere((e) => e.kind == envKindPour).payload,
      );
      expect(finalFrame.state, pourStateFinal);
      expect(finalFrame.pouredTotal, poured);

      final ledgerState = await rig.container.read(
        ledgerControllerProvider.future,
      );
      expect(
        ledgerState.ordered.where((t) => t.amount == poured),
        hasLength(1),
      );
      expect(find.byKey(const Key('pour.done')), findsOneWidget);
    },
  );

  testWidgets(
    'shake during the grace window aborts — after biometric approval, no '
    'tx sent',
    (tester) async {
      final rig = await _buildRig(tester);
      final ticker = StreamController<void>.broadcast();
      addTearDown(ticker.close);
      // Never-timing-out grace window: only the shake can resolve it, and
      // (unlike Future.delayed) this never registers a real Timer, so there
      // is nothing left pending when the test ends.
      final neverTimesOut = GraceWindow(
        scheduler: (_) => Completer<void>().future,
      );

      await _pump(
        tester,
        rig.container,
        PourScreen(
          to: 'receiver-addr',
          ticker: ticker.stream,
          graceWindow: neverTimesOut,
        ),
      );

      await tester.tap(find.byKey(const Key('pour.start')));
      await tester.pump();
      rig.motion.emitTilt(10);
      await tester.pump();
      ticker.add(null);
      await tester.pump();

      await tester.tap(find.byKey(const Key('pour.stop')));
      await tester.pump(); // stopPour() resolves
      await tester.pump(); // authenticate() resolves -> grace window arms
      expect(find.textContaining('shake to cancel'), findsOneWidget);

      // Biometric gate runs BEFORE the grace window (spec §3: post-
      // biometric, pre-sign), so it has already fired by this point.
      expect(rig.gate.authCalls, 1);

      rig.motion.emitShake();
      await tester.pumpAndSettle();

      expect(
        rig.transport.sentFrames
            .map(decodeFrame)
            .where((e) => e.kind == envKindTx),
        isEmpty,
      );
      expect(find.textContaining('cancelled'), findsWidgets);

      final ledgerState = await rig.container.read(
        ledgerControllerProvider.future,
      );
      expect(ledgerState.ordered.length, 1); // only the mint
    },
  );
}
