import 'package:cash_me_outside/theme/coin.dart';
import 'package:cash_me_outside/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette matches spec', () {
    expect(CmoColors.green, const Color(0xFF3E6B4F));
    expect(CmoColors.cream, const Color(0xFFF2EBD9));
    expect(CmoColors.orange, const Color(0xFFFF5A1F));
    expect(CmoColors.navy, const Color(0xFF1E2733));
    expect(CmoColors.brass, const Color(0xFFC9A54A));
  });

  testWidgets('coin renders and its flip animation terminates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PinnieCoin(flipOnBuild: true))),
    );
    expect(find.byType(PinnieCoin), findsOneWidget);
    await tester.pumpAndSettle(); // hangs forever if the animation loops
  });
}
