import 'package:cash_me_outside/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const CashMeOutsideApp());
    expect(find.text('Cash Me Outside'), findsOneWidget);
  });
}
