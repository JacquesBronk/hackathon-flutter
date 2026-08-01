import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/features/history/history_screen.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('lists transactions; transfer rows re-show their tx QR', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: fakeHardwareOverrides());
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    await container.read(peerDirectoryProvider).record(peer.address, 'Anna');
    final tx = await container
        .read(ledgerControllerProvider.notifier)
        .send(to: peer.address, amount: 30, memo: 'coffee');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Unauthenticated peer name always renders WITH the truncated address.
    expect(find.textContaining('Anna'), findsOneWidget);
    await tester.tap(find.textContaining('Anna'));
    await tester.pumpAndSettle();
    expect(find.textContaining('coffee'), findsOneWidget);
    await tester.tap(find.byKey(Key('history.showcode.${tx.id}')));
    await tester.pumpAndSettle();
    expect(
      find.byType(QrImageView),
      findsOneWidget,
    ); // stranded-delivery recovery
  });
}
