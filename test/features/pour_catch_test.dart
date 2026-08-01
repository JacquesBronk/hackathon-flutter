import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/features/pour/catch_screen.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class _Rig {
  _Rig({required this.container, required this.transport, required this.myAddr});
  final ProviderContainer container;
  final FakeMeshTransport transport;
  final String myAddr;
}

// Provider wiring happens inline per test (not in setUp()) — see pour_test.dart
// for why a package:test setUp() callback leaves Riverpod's Flutter-vsync
// batched notifications unflushed across plain tester.pump() calls.
Future<_Rig> _buildRig(WidgetTester tester) async {
  final transport = FakeMeshTransport();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(meshTransport: transport),
  );
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Catcher', avatar: '🦔');
  final myAddr = (await container.read(walletKeysProvider.future))!.address;
  await container.read(meshControllerProvider.future);
  await container.read(pourControllerProvider.future);
  return _Rig(container: container, transport: transport, myAddr: myAddr);
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CatchScreen()),
    ),
  );
  // pumpAndSettle (not a bare pump()) so the zero-duration Timer Riverpod
  // schedules from createWallet()'s ref.invalidate(walletKeysProvider) (see
  // _buildRig) actually elapses instead of tripping flutter_test's "Timer
  // still pending" invariant at teardown.
  await tester.pumpAndSettle();
}

// Drains the gossip chain (transport -> engine -> MeshController ->
// PourController fold) across several microtask boundaries — same rationale
// as mesh_send_test.dart's _flushMesh: pumpEventQueue() deadlocks under
// testWidgets, plain pump() drains the broadcast-stream microtasks instead.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

MeshEnvelope _frame({
  required String to,
  required int seq,
  required int pouredTotal,
}) => MeshEnvelope(
  msgId: _uuid.v7(),
  kind: envKindPour,
  origin: 'far-away',
  target: to,
  ttl: meshInitialTtl,
  path: const [],
  payload: pourPayload(
    sessionId: 'session-1',
    seq: seq,
    pouredTotal: pouredTotal,
    state: pourStatePouring,
  ),
);

void main() {
  testWidgets('no pour yet: waiting message, no cup', (tester) async {
    final rig = await _buildRig(tester);
    await _pump(tester, rig.container);
    expect(find.textContaining('Waiting'), findsOneWidget);
    expect(find.byKey(const Key('pour.catch.cup')), findsNothing);
  });

  testWidgets(
    'cup fills from the highest-seq envelope; out-of-order arrival is safe',
    (tester) async {
      final rig = await _buildRig(tester);
      await _pump(tester, rig.container);

      // seq 2 arrives before seq 1 (relay reordering) — the fold must keep
      // seq 2's total, matching the domain-level guarantee in
      // applyPourFrame (state/pour_controller.dart).
      rig.transport.injectFrame(
        encodeFrame(_frame(to: rig.myAddr, seq: 2, pouredTotal: 15)),
      );
      await _flush(tester);
      rig.transport.injectFrame(
        encodeFrame(_frame(to: rig.myAddr, seq: 1, pouredTotal: 6)),
      );
      await _flush(tester);

      expect(find.text('ᵽ15'), findsOneWidget);
      final cup = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('pour.catch.cup')),
      );
      expect(cup.heightFactor, closeTo(15 / 25, 1e-9));
    },
  );

  testWidgets('final envelope shows the caught celebration', (tester) async {
    final rig = await _buildRig(tester);
    await _pump(tester, rig.container);
    rig.transport.injectFrame(
      encodeFrame(_frame(to: rig.myAddr, seq: 0, pouredTotal: 9)),
    );
    await _flush(tester);
    rig.transport.injectFrame(
      encodeFrame(
        MeshEnvelope(
          msgId: _uuid.v7(),
          kind: envKindPour,
          origin: 'far-away',
          target: rig.myAddr,
          ttl: meshInitialTtl,
          path: const [],
          payload: pourPayload(
            sessionId: 'session-1',
            seq: 1,
            pouredTotal: 9,
            state: pourStateFinal,
            txId: 'tx-1',
          ),
        ),
      ),
    );
    await _flush(tester);

    expect(find.text('+ᵽ9'), findsOneWidget);
    expect(find.text('Caught it!'), findsOneWidget);
  });
}
