import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/voucher.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/nfc_fakes.dart';
import 'package:cash_me_outside/features/nfc/sticker_studio.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

late FakeNfcPort nfcPort;
late FakeBiometricGate gate;

Future<ProviderContainer> pumpStickerStudio(
  WidgetTester tester, {
  bool approve = true,
}) async {
  nfcPort = FakeNfcPort();
  gate = FakeBiometricGate(approve: approve);
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(nfcPort: nfcPort, gate: gate),
  );
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Me', avatar: '🦫');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StickerStudio()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('write request sticker writes an rr1 tag with the entered amount', (
    tester,
  ) async {
    await pumpStickerStudio(tester);
    await tester.enterText(
      find.byKey(const Key('sticker.request.amount')),
      '15',
    );
    await tester.tap(find.byKey(const Key('nfc.write.request')));
    await tester.pumpAndSettle();

    expect(nfcPort.writtenTags, hasLength(1));
    final rr = decodeQr(nfcPort.writtenTags.single) as ReceiveRequest;
    expect(rr.amount, 15);
  });

  testWidgets('write voucher sticker requires biometric approval', (
    tester,
  ) async {
    await pumpStickerStudio(tester, approve: false);
    await tester.enterText(find.byKey(const Key('nfc.voucher.amount')), '50');
    await tester.tap(find.byKey(const Key('nfc.write.voucher')));
    await tester.pumpAndSettle();

    expect(gate.authCalls, 1);
    expect(nfcPort.writtenTags, isEmpty);
    expect(find.text('Biometric check failed'), findsOneWidget);
  });

  testWidgets('write voucher sticker: approved mints and writes a v1 tag', (
    tester,
  ) async {
    await pumpStickerStudio(tester);
    await tester.enterText(find.byKey(const Key('nfc.voucher.amount')), '50');
    await tester.tap(find.byKey(const Key('nfc.write.voucher')));
    await tester.pumpAndSettle();

    expect(gate.authCalls, 1);
    expect(nfcPort.writtenTags, hasLength(1));
    final voucher = decodeQr(nfcPort.writtenTags.single) as VoucherPayload;
    expect(voucher.tx.amount, 50);
  });

  testWidgets('invalid voucher amount: friendly error, nothing written', (
    tester,
  ) async {
    await pumpStickerStudio(tester);
    await tester.enterText(find.byKey(const Key('nfc.voucher.amount')), '0');
    await tester.tap(find.byKey(const Key('nfc.write.voucher')));
    await tester.pumpAndSettle();

    expect(gate.authCalls, 0);
    expect(nfcPort.writtenTags, isEmpty);
    expect(find.textContaining("not a real amount"), findsOneWidget);
  });

  testWidgets(
    'injected voucher read claims it: banner shows +ᵽN, balance moves',
    (tester) async {
      final owner = await WalletKeys.fromSeed(List.filled(32, 9));
      final (voucherUri, _) = await mintVoucher(
        owner: owner,
        amount: 75,
        lamportTs: 2,
      );

      final container = await pumpStickerStudio(tester);
      final selfAddr = (await container.read(walletKeysProvider.future))!
          .address;

      expect(find.byKey(const Key('nfc.claim.result')), findsNothing);

      nfcPort.injectRead(voucherUri);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nfc.claim.result')), findsOneWidget);
      expect(find.text('+ᵽ75'), findsOneWidget);
      final state = await container.read(ledgerControllerProvider.future);
      expect(state.balances[selfAddr], 575); // 500 mint + 75 claimed
    },
  );
}
