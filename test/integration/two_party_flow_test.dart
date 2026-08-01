import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets(
    'full two-party flow: onboard → send to peer → receive from peer → history',
    (tester) async {
      final scanner = FakeQrScanner();
      final container = ProviderContainer(
        overrides: fakeHardwareOverrides(scanner: scanner),
      );
      addTearDown(container.dispose);
      // NOTE: overrides live on the CONTAINER only. CashMeOutsideApp's inner
      // ProviderScope must stay override-free under this harness — passing
      // overrides to the app would fork those providers into the child scope
      // and silently diverge from what container.read(...) sees.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CashMeOutsideApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Onboard.
      await tester.enterText(find.byKey(const Key('onboard.name')), 'Jacques');
      await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
      await tester.tap(find.byKey(const Key('onboard.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.mint.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboard.biometric')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ᵽ500'), findsWidgets);
      final myAddr = (await container.read(walletKeysProvider.future))!.address;

      // The test IS the counterparty: Anna's device exists only as keys + payloads.
      final anna = await WalletKeys.fromSeed(List.filled(32, 11));

      // SEND: navigate, "scan" Anna's rr, confirm, biometric, tx QR, done.
      await tester.tap(find.byKey(const Key('wallet.send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send.method.qr')));
      await tester.pumpAndSettle();
      scanner.emit(
        encodeReceiveRequest(
          ReceiveRequest(addr: anna.address, name: 'Anna', amount: 120),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send.confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.tap(find.byKey(const Key('send.done')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ᵽ380'), findsWidgets); // 500 - 120

      // RECEIVE: Anna pays 75 back; her tx arrives as a scanned QR.
      final annaTx = await buildSigned(
        keys: anna,
        to: myAddr,
        amount: 75,
        type: txTypeTransfer,
        lamportTs: 5,
      );
      await tester.tap(find.byIcon(Icons.qr_code));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('receive.scan')));
      await tester.pumpAndSettle();
      scanner.emit(encodeTransaction(annaTx));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ᵽ75'), findsOneWidget);

      // Ledger truth: both directions applied.
      final state = await container.read(ledgerControllerProvider.future);
      expect(state.balances[myAddr], 455); // 500 - 120 + 75
      expect(state.balances[anna.address], 45); // 120 - 75
      expect(state.ordered.length, 3);
    },
  );

  testWidgets('onboarding persists: relaunch lands on unlock, not onboarding', (
    tester,
  ) async {
    final profileStore = InMemoryProfileStore();
    final vault = InMemoryKeyVault();
    final overrides = [
      ...fakeHardwareOverrides(),
      profileStoreProvider.overrideWithValue(profileStore),
      keyVaultProvider.overrideWithValue(vault),
    ];
    // First launch: onboard fully.
    var container = ProviderContainer(overrides: overrides);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CashMeOutsideApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.biometric')));
    await tester.pumpAndSettle();
    // Tear the tree down COMPLETELY before disposing: pumping the identical
    // const widget again would never rebuild it, and the inner ProviderScope
    // would wrap a disposed container (ancestor-change assert in riverpod).
    await tester.pumpWidget(const SizedBox());
    container.dispose();

    // "Relaunch": same stores, fresh container — must hit unlock then wallet.
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CashMeOutsideApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.byKey(const Key('onboard.name')), findsNothing);
  });
}
