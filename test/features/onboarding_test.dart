import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('happy path: name → avatar → mint → biometric → wallet ᵽ500', (
    tester,
  ) async {
    await tester.pumpWidget(
      CashMeOutsideApp(overrides: fakeHardwareOverrides()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboard.name')), 'Jacques');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboard.biometric')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.textContaining('500'), findsWidgets);
  });

  testWidgets(
    'no biometrics available: skip-with-warning path lands in wallet',
    (tester) async {
      await tester.pumpWidget(
        CashMeOutsideApp(
          overrides: fakeHardwareOverrides(
            gate: FakeBiometricGate(available: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
      await tester.tap(find.byKey(const Key('onboard.avatar.🦔')));
      await tester.tap(find.byKey(const Key('onboard.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.mint.next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboard.skip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboard.skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    },
  );
}
