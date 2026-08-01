import 'dart:math';

import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:cash_me_outside/state/rain_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitRain', () {
    final recipients = ['a', 'b', 'c', 'd', 'e'];

    test('every share >= 1 and shares sum exactly to total', () {
      for (final seed in [1, 2, 3, 42, 999]) {
        final shares = splitRain(100, recipients, random: Random(seed));
        expect(shares, hasLength(recipients.length));
        expect(shares.every((s) => s >= 1), isTrue, reason: 'seed $seed');
        expect(shares.reduce((a, b) => a + b), 100, reason: 'seed $seed');
      }
    });

    test('deterministic given the same seeded Random', () {
      final a = splitRain(250, recipients, random: Random(7));
      final b = splitRain(250, recipients, random: Random(7));
      expect(a, b);
    });

    test('total exactly equal to recipient count gives everyone 1', () {
      final shares = splitRain(5, recipients, random: Random(1));
      expect(shares, [1, 1, 1, 1, 1]);
    });

    test('single recipient gets the whole total', () {
      final shares = splitRain(37, ['only'], random: Random(1));
      expect(shares, [37]);
    });

    test('throws when total < recipient count', () {
      expect(
        () => splitRain(4, recipients, random: Random(1)),
        throwsArgumentError,
      );
    });

    test('throws with no recipients', () {
      expect(
        () => splitRain(10, const [], random: Random(1)),
        throwsArgumentError,
      );
    });
  });

  group('RainController (wired)', () {
    late ProviderContainer container;
    late FakeMeshTransport transport;
    late FakeBiometricGate gate;

    setUp(() async {
      transport = FakeMeshTransport();
      gate = FakeBiometricGate();
      container = ProviderContainer(
        overrides: fakeHardwareOverrides(meshTransport: transport, gate: gate),
      );
      addTearDown(container.dispose);
      await container
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Rainer', avatar: '🦄');
      await container.read(meshControllerProvider.future);
      await container.read(rainControllerProvider.future);
    });

    test(
      'makeItRain sends one tx per recipient with a single biometric call',
      () async {
        final controller = container.read(rainControllerProvider.notifier);
        final txIds = await controller.makeItRain(
          total: 30,
          recipients: ['p1', 'p2', 'p3'],
          random: Random(5),
        );
        await pumpEventQueue();

        expect(gate.authCalls, 1);
        expect(txIds, isNotNull);
        expect(txIds, hasLength(3));

        final txFrames = transport.sentFrames
            .map(decodeFrame)
            .where((e) => e.kind == envKindTx)
            .toList();
        expect(txFrames, hasLength(3));
        expect(txFrames.map((f) => f.target).toSet(), {'p1', 'p2', 'p3'});

        final ledgerState = await container.read(
          ledgerControllerProvider.future,
        );
        final transferAmounts = ledgerState.ordered
            .where((t) => t.type == 'transfer')
            .map((t) => t.amount)
            .toList();
        expect(transferAmounts.length, 3);
        expect(transferAmounts.reduce((a, b) => a + b), 30);
        expect(transferAmounts.every((a) => a >= 1), isTrue);
      },
    );

    test('denied biometrics sends no tx at all', () async {
      final denyContainer = ProviderContainer(
        overrides: fakeHardwareOverrides(
          meshTransport: FakeMeshTransport(),
          gate: FakeBiometricGate(approve: false),
        ),
      );
      addTearDown(denyContainer.dispose);
      await denyContainer
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Denier', avatar: '🦉');
      await denyContainer.read(meshControllerProvider.future);
      await denyContainer.read(rainControllerProvider.future);

      final controller = denyContainer.read(rainControllerProvider.notifier);
      final txIds = await controller.makeItRain(
        total: 10,
        recipients: ['x', 'y'],
        random: Random(1),
      );

      expect(txIds, isNull);
      final ledgerState = await denyContainer.read(
        ledgerControllerProvider.future,
      );
      expect(ledgerState.ordered.where((t) => t.type == 'transfer'), isEmpty);
    });

    test(
      'invalid split (total < recipients) throws before biometric',
      () async {
        final controller = container.read(rainControllerProvider.notifier);
        await expectLater(
          () => controller.makeItRain(
            total: 1,
            recipients: ['a', 'b', 'c'],
            random: Random(1),
          ),
          throwsArgumentError,
        );
        expect(gate.authCalls, 0);
      },
    );
  });
}
