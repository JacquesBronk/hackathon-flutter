import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/mesh/envelope.dart';
import 'package:cash_me_outside/fakes/mesh_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-hardware bootstrap (app.dart's `_MeshRealWiring`) broadcasts presence
/// on start and every 30s (spec §2.2 rule 7) — this is the sole place
/// periodic timers live, so it's the only place that cadence is testable.
void main() {
  testWidgets(
    'presence cadence: broadcasts on start + every 30s; dispose cancels the '
    'timer with no pending-timer failure',
    (tester) async {
      final transport = FakeMeshTransport();
      final container = ProviderContainer(
        overrides: fakeHardwareOverrides(meshTransport: transport),
      );
      addTearDown(container.dispose);
      await container
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Timer', avatar: '🦫');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CashMeOutsideApp(enableMeshRealWiring: true),
        ),
      );
      // Drain the async start chain: build() -> transport.start() ->
      // broadcastPresenceOnce() -> Timer.periodic registration.
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      int presenceFrameCount() => transport.sentFrames
          .map(decodeFrame)
          .where((e) => e.kind == envKindPresence)
          .length;

      expect(presenceFrameCount(), 1); // start

      await tester.pump(const Duration(seconds: 31));
      expect(presenceFrameCount(), 2); // first 30s tick

      await tester.pump(const Duration(seconds: 31));
      expect(presenceFrameCount(), 3); // second 30s tick

      // Unmount to trigger _MeshRealWiringState.dispose(); if the timer
      // weren't cancelled, the test binding fails with a pending-timer
      // error once this test completes.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
