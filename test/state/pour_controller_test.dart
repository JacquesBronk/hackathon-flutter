import 'dart:async';

import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:cash_me_outside/state/pour_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  group('pourRatePerSecond', () {
    test('is zero at and below the 0.35 rad threshold', () {
      expect(pourRatePerSecond(0.35), 0);
      expect(pourRatePerSecond(0.1), 0);
      expect(pourRatePerSecond(0), 0);
    });

    test('is clamped to 25 pinnies/sec at full tilt and beyond', () {
      expect(pourRatePerSecond(0.35 + 1.2), closeTo(25, 1e-9));
      expect(pourRatePerSecond(10), 25); // way past vertical — still clamped
    });

    test('scales linearly between the threshold and full tilt', () {
      // Halfway up the ramp -> half the max rate.
      expect(pourRatePerSecond(0.35 + 0.6), closeTo(12.5, 1e-9));
    });
  });

  group('PourAccumulator', () {
    test('accumulates whole pinnies and reports the gain per tick', () {
      final acc = PourAccumulator();
      // Full tilt: 25 pinnies/sec * 0.25s/tick = 6.25 pinnies/tick.
      expect(acc.tick(10), 6); // 6.25 -> floor 6
      expect(acc.pouredTotal, 6);
      expect(acc.tick(10), 6); // 12.5 -> floor 12, gained 6
      expect(acc.pouredTotal, 12);
      expect(acc.tick(10), 6); // 18.75 -> floor 18, gained 6
      expect(acc.pouredTotal, 18);
    });

    test('fractional pinnies carry over across ticks (integer boundary)', () {
      final acc = PourAccumulator();
      // A slow tilt accumulates well under 1 pinnie/tick — the boundary
      // must still be crossed eventually instead of the fraction being
      // dropped each tick. Avoid pinning an exact tick count (float
      // summation isn't bit-exact); just assert it took more than one tick.
      const tilt = 0.35 + 0.006; // rate = (0.006/1.2)*25 = 0.125 pinnies/sec
      var ticks = 0;
      var gained = 0;
      while (gained == 0 && ticks < 1000) {
        gained = acc.tick(tilt);
        ticks++;
      }
      expect(acc.pouredTotal, 1);
      expect(ticks, greaterThan(1));
    });

    test('tilting back below threshold pauses accumulation (rate 0)', () {
      final acc = PourAccumulator();
      acc.tick(10); // pours some
      final before = acc.pouredTotal;
      expect(acc.tick(0.1), 0); // below threshold -> no gain
      expect(acc.pouredTotal, before);
    });
  });

  group('applyPourFrame', () {
    MeshEnvelope frame({
      required String sessionId,
      required int seq,
      required int pouredTotal,
      String state = pourStatePouring,
      String? txId,
    }) => MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindPour,
      origin: 'sender',
      target: 'receiver',
      ttl: meshInitialTtl,
      path: const [],
      payload: pourPayload(
        sessionId: sessionId,
        seq: seq,
        pouredTotal: pouredTotal,
        state: state,
        txId: txId,
      ),
    );

    test('first frame establishes catch state', () {
      final result = applyPourFrame(
        null,
        frame(sessionId: 's1', seq: 0, pouredTotal: 3),
      );
      expect(result.sessionId, 's1');
      expect(result.seq, 0);
      expect(result.pouredTotal, 3);
    });

    test('higher seq within the same session advances state', () {
      final first = applyPourFrame(
        null,
        frame(sessionId: 's1', seq: 0, pouredTotal: 3),
      );
      final next = applyPourFrame(
        first,
        frame(sessionId: 's1', seq: 1, pouredTotal: 9),
      );
      expect(next.pouredTotal, 9);
      expect(next.seq, 1);
    });

    test('an out-of-order (lower/equal seq) frame is ignored', () {
      final first = applyPourFrame(
        null,
        frame(sessionId: 's1', seq: 5, pouredTotal: 20),
      );
      final stale = applyPourFrame(
        first,
        frame(sessionId: 's1', seq: 2, pouredTotal: 8),
      );
      expect(identical(stale, first), isTrue);
      final dup = applyPourFrame(
        first,
        frame(sessionId: 's1', seq: 5, pouredTotal: 999),
      );
      expect(identical(dup, first), isTrue);
    });

    test('a different sessionId always supersedes, even at seq 0', () {
      final first = applyPourFrame(
        null,
        frame(sessionId: 's1', seq: 8, pouredTotal: 40),
      );
      final newSession = applyPourFrame(
        first,
        frame(sessionId: 's2', seq: 0, pouredTotal: 1),
      );
      expect(newSession.sessionId, 's2');
      expect(newSession.pouredTotal, 1);
    });

    test('final state carries the txId through', () {
      final result = applyPourFrame(
        null,
        frame(
          sessionId: 's1',
          seq: 3,
          pouredTotal: 25,
          state: pourStateFinal,
          txId: 'tx-1',
        ),
      );
      expect(result.state, pourStateFinal);
      expect(result.txId, 'tx-1');
    });
  });

  group('PourController (wired)', () {
    late ProviderContainer container;
    late FakeMotionSensor motion;
    late FakeHaptics haptics;
    late FakeMeshTransport transport;
    late FakeBiometricGate gate;

    setUp(() async {
      motion = FakeMotionSensor();
      haptics = FakeHaptics();
      transport = FakeMeshTransport();
      gate = FakeBiometricGate();
      container = ProviderContainer(
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
      await container.read(meshControllerProvider.future);
      await container.read(pourControllerProvider.future);
    });

    test(
      'tilt-driven ticks pour, tick haptics fire, envelopes stream',
      () async {
        final ticker = StreamController<void>.broadcast();
        final controller = container.read(pourControllerProvider.notifier);
        await controller.startPour(to: 'receiver-addr', ticker: ticker.stream);

        motion.emitTilt(10); // full tilt
        await pumpEventQueue();
        ticker.add(null);
        await pumpEventQueue();

        final state = container.read(pourControllerProvider).value!;
        expect(state.outgoing!.active, isTrue);
        expect(state.outgoing!.pouredTotal, greaterThan(0));
        expect(haptics.tickCount, state.outgoing!.pouredTotal);

        final pourFrames = transport.sentFrames
            .map(decodeFrame)
            .where((e) => e.kind == envKindPour);
        expect(pourFrames, isNotEmpty);
        final parsed = parsePourPayload(pourFrames.last.payload);
        expect(parsed.state, pourStatePouring);
        expect(parsed.pouredTotal, state.outgoing!.pouredTotal);

        await ticker.close();
      },
    );

    test('stopPour emits a stopped envelope and halts ticking', () async {
      final ticker = StreamController<void>.broadcast();
      final controller = container.read(pourControllerProvider.notifier);
      await controller.startPour(to: 'receiver-addr', ticker: ticker.stream);
      motion.emitTilt(10);
      await pumpEventQueue();
      ticker.add(null);
      await pumpEventQueue();

      await controller.stopPour();
      await pumpEventQueue();

      final state = container.read(pourControllerProvider).value!;
      expect(state.outgoing!.active, isFalse);
      final frames = transport.sentFrames
          .map(decodeFrame)
          .where((e) => e.kind == envKindPour)
          .toList();
      expect(parsePourPayload(frames.last.payload).state, pourStateStopped);

      // No further accumulation after stop — ticking on the (closed sub)
      // ticker must not crash or emit more frames.
      final framesBefore = frames.length;
      ticker.add(null);
      await pumpEventQueue();
      final framesAfter = transport.sentFrames
          .map(decodeFrame)
          .where((e) => e.kind == envKindPour)
          .length;
      expect(framesAfter, framesBefore);
      await ticker.close();
    });

    test(
      'finishPour biometric-gates, sends exactly one signed tx, emits final envelope',
      () async {
        final ticker = StreamController<void>.broadcast();
        final controller = container.read(pourControllerProvider.notifier);
        await controller.startPour(to: 'receiver-addr', ticker: ticker.stream);
        motion.emitTilt(10);
        await pumpEventQueue();
        ticker.add(null);
        ticker.add(null);
        await pumpEventQueue();

        final pouredBefore = container
            .read(pourControllerProvider)
            .value!
            .outgoing!
            .pouredTotal;
        expect(pouredBefore, greaterThan(0));

        final sent = await controller.finishPour();
        await pumpEventQueue();

        expect(sent, isTrue);
        expect(gate.authCalls, 1);

        final frames = transport.sentFrames.map(decodeFrame).toList();
        final txFrames = frames.where((e) => e.kind == envKindTx).toList();
        expect(txFrames, hasLength(1)); // exactly one signed tx

        final pourFrames = frames.where((e) => e.kind == envKindPour).toList();
        final finalFrame = parsePourPayload(pourFrames.last.payload);
        expect(finalFrame.state, pourStateFinal);
        expect(finalFrame.pouredTotal, pouredBefore);
        expect(finalFrame.txId, isNotNull);

        final ledgerState = await container.read(
          ledgerControllerProvider.future,
        );
        expect(
          ledgerState.ordered.where((t) => t.amount == pouredBefore),
          hasLength(1),
        );
        await ticker.close();
      },
    );

    test('finishPour sends no tx when biometrics are denied', () async {
      final denyMotion = FakeMotionSensor();
      final denyingContainer = ProviderContainer(
        overrides: fakeHardwareOverrides(
          motionSensor: denyMotion,
          meshTransport: FakeMeshTransport(),
          gate: FakeBiometricGate(approve: false),
        ),
      );
      addTearDown(denyingContainer.dispose);
      await denyingContainer
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Denier', avatar: '🦔');
      await denyingContainer.read(meshControllerProvider.future);
      await denyingContainer.read(pourControllerProvider.future);

      final ticker = StreamController<void>.broadcast();
      final controller = denyingContainer.read(pourControllerProvider.notifier);
      await controller.startPour(to: 'receiver-addr', ticker: ticker.stream);
      denyMotion.emitTilt(10);
      await pumpEventQueue();
      ticker.add(null);
      await pumpEventQueue();

      final sent = await controller.finishPour();
      await pumpEventQueue();

      expect(sent, isFalse);
      final ledgerState = await denyingContainer.read(
        ledgerControllerProvider.future,
      );
      expect(ledgerState.ordered.where((t) => t.type == 'transfer'), isEmpty);
      await ticker.close();
    });

    test(
      'finishPour with nothing poured (0 accumulated) sends no tx',
      () async {
        final controller = container.read(pourControllerProvider.notifier);
        await controller.startPour(
          to: 'receiver-addr',
          ticker: const Stream.empty(),
        );
        final sent = await controller.finishPour();
        expect(sent, isFalse);
        expect(gate.authCalls, 0);
      },
    );

    test('incoming pour envelopes fold into catch state', () async {
      final other = await container.read(walletKeysProvider.future);
      final sessionId = _uuid.v7();
      final envelope = MeshEnvelope(
        msgId: _uuid.v7(),
        kind: envKindPour,
        origin: 'far-away',
        target: other!.address,
        ttl: meshInitialTtl,
        path: const [],
        payload: pourPayload(
          sessionId: sessionId,
          seq: 0,
          pouredTotal: 4,
          state: pourStatePouring,
        ),
      );
      transport.injectFrame(encodeFrame(envelope));
      await pumpEventQueue();

      final state = container.read(pourControllerProvider).value!;
      expect(state.catchState!.sessionId, sessionId);
      expect(state.catchState!.pouredTotal, 4);
    });

    test(
      'catch state renders correctly from out-of-order envelope arrival',
      () async {
        final other = await container.read(walletKeysProvider.future);
        final sessionId = _uuid.v7();
        MeshEnvelope frameFor(int seq, int total) => MeshEnvelope(
          msgId: _uuid.v7(),
          kind: envKindPour,
          origin: 'far-away',
          target: other!.address,
          ttl: meshInitialTtl,
          path: const [],
          payload: pourPayload(
            sessionId: sessionId,
            seq: seq,
            pouredTotal: total,
            state: pourStatePouring,
          ),
        );
        // seq 2 arrives before seq 1 (relay reordering).
        transport.injectFrame(encodeFrame(frameFor(2, 12)));
        await pumpEventQueue();
        transport.injectFrame(encodeFrame(frameFor(1, 6)));
        await pumpEventQueue();

        final state = container.read(pourControllerProvider).value!;
        expect(state.catchState!.seq, 2);
        expect(state.catchState!.pouredTotal, 12); // stale seq 1 ignored
      },
    );
  });
}
