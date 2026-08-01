import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/features/receive/receive_screen.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('shows own rr QR; scan-back ingests a valid tx', (tester) async {
    final scanner = FakeQrScanner();
    final container = ProviderContainer(
      overrides: fakeHardwareOverrides(scanner: scanner),
    );
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final myAddr = (await container.read(walletKeysProvider.future))!.address;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReceiveScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byKey(const Key('receive.scan')));
    await tester.pumpAndSettle();
    final sender = await WalletKeys.fromSeed(List.filled(32, 6));
    final tx = await buildSigned(
      keys: sender,
      to: myAddr,
      amount: 75,
      type: txTypeTransfer,
      lamportTs: 3,
    );
    scanner.emit(encodeTransaction(tx));
    await tester.pumpAndSettle();
    expect(find.textContaining('+ᵽ75'), findsOneWidget);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[myAddr], 575);
  });

  testWidgets('forged tx → "Counterfeit pinnies rejected"', (tester) async {
    final scanner = FakeQrScanner();
    final container = ProviderContainer(
      overrides: fakeHardwareOverrides(scanner: scanner),
    );
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final myAddr = (await container.read(walletKeysProvider.future))!.address;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReceiveScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive.scan')));
    await tester.pumpAndSettle();
    final sender = await WalletKeys.fromSeed(List.filled(32, 6));
    final tx = await buildSigned(
      keys: sender,
      to: myAddr,
      amount: 75,
      type: txTypeTransfer,
      lamportTs: 3,
    );
    final forged = Transaction(
      id: tx.id,
      type: tx.type,
      from: tx.from,
      to: tx.to,
      amount: 9999,
      memo: tx.memo,
      lamportTs: tx.lamportTs,
      signature: tx.signature,
    );
    scanner.emit(encodeTransaction(forged));
    await tester.pumpAndSettle();
    expect(find.text('Counterfeit pinnies rejected'), findsOneWidget);
  });
}
