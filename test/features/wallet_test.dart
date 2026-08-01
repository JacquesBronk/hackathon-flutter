import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> onboard(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
  await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
  await tester.tap(find.byKey(const Key('onboard.next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboard.mint.next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboard.biometric')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('balance hero shows ᵽ500; radial menu has only QR enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      CashMeOutsideApp(overrides: fakeHardwareOverrides()),
    );
    await onboard(tester);
    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.textContaining('ᵽ'), findsWidgets);
    await tester.tap(find.byKey(const Key('wallet.send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('send.method.qr')), findsOneWidget);
    expect(find.textContaining('soon'), findsWidgets);
  });
}
