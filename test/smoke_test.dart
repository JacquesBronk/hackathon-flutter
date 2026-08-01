import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to onboarding', (tester) async {
    await tester.pumpWidget(
      CashMeOutsideApp(overrides: fakeHardwareOverrides()),
    );
    await tester.pumpAndSettle();
    expect(find.text("Who's getting paid?"), findsOneWidget);
  });
}
