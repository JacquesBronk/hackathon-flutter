import 'dart:async';

import 'package:cash_me_outside/fakes/sensor_fakes.dart';
import 'package:cash_me_outside/features/send/grace_window_widget.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:cash_me_outside/state/grace_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FakeHaptics? haptics,
    FakeMotionSensor? motionSensor,
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: fakeHardwareOverrides(
        haptics: haptics,
        motionSensor: motionSensor,
      ),
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      ),
    ),
  );

  testWidgets('window elapses undisturbed: onDecided(true), no haptic', (
    tester,
  ) async {
    final haptics = FakeHaptics();
    bool? decided;
    await pump(
      tester,
      GraceWindowWidget(
        pendingId: 'tx1',
        window: const Duration(seconds: 5),
        onDecided: (v) => decided = v,
      ),
      haptics: haptics,
    );
    expect(find.byKey(const Key('send.grace.tx1')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(decided, isTrue);
    expect(haptics.tickCount, 0);
  });

  testWidgets('shake aborts before the window elapses: onDecided(false), '
      'haptic tick fires', (tester) async {
    final haptics = FakeHaptics();
    final motionSensor = FakeMotionSensor();
    bool? decided;
    await pump(
      tester,
      GraceWindowWidget(
        pendingId: 'tx2',
        window: const Duration(seconds: 5),
        onDecided: (v) => decided = v,
      ),
      haptics: haptics,
      motionSensor: motionSensor,
    );

    await tester.pump(const Duration(seconds: 1));
    motionSensor.emitShake();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(decided, isFalse);
    expect(haptics.tickCount, 1);

    // A late timeout after the abort must not flip the decision again.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(decided, isFalse);
    expect(haptics.tickCount, 1);
  });

  testWidgets('cancel button aborts identically to a shake (accessibility '
      'fallback — no motion required)', (tester) async {
    final haptics = FakeHaptics();
    bool? decided;
    await pump(
      tester,
      GraceWindowWidget(
        pendingId: 'tx3',
        window: const Duration(seconds: 5),
        onDecided: (v) => decided = v,
      ),
      haptics: haptics,
    );

    await tester.tap(find.byKey(const Key('send.grace.cancel.tx3')));
    await tester.pumpAndSettle();

    expect(decided, isFalse);
    expect(haptics.tickCount, 1);

    // Drain the real 5s timer behind the default GraceWindow's scheduler
    // (aborted early, so it's still pending — ignored on fire, but the test
    // binding asserts no dangling timers survive the test).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: renders a static countdown, no looping '
      'animation to hang pumpAndSettle', (tester) async {
    bool? decided;
    await pump(
      tester,
      GraceWindowWidget(
        pendingId: 'tx4',
        window: const Duration(seconds: 5),
        onDecided: (v) => decided = v,
      ),
      reducedMotion: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('send.grace.tx4')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(decided, isTrue);
  });

  testWidgets('accepts an injected GraceWindow for deterministic control', (
    tester,
  ) async {
    final timeout = Completer<void>();
    final abort = StreamController<void>.broadcast();
    addTearDown(abort.close);
    bool? decided;
    await pump(
      tester,
      GraceWindowWidget(
        pendingId: 'tx5',
        graceWindow: GraceWindow(scheduler: (_) => timeout.future),
        abortSignal: abort.stream,
        onDecided: (v) => decided = v,
      ),
    );

    expect(decided, isNull);
    timeout.complete();
    await tester.pumpAndSettle();
    expect(decided, isTrue);
  });
}
