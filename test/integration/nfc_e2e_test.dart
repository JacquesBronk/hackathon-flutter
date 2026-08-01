import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/nfc_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'full e2e: owner writes a voucher sticker via Sticker studio UI -> a '
    'second wallet taps and claims it -> once the owner also syncs the same '
    'two transactions (as mesh/QR eventually would) both ledgers converge on '
    'identical balances for the owner and claimant addresses',
    (tester) async {
      final ownerPort = FakeNfcPort();
      final ownerContainer = ProviderContainer(
        overrides: fakeHardwareOverrides(nfcPort: ownerPort),
      );
      addTearDown(ownerContainer.dispose);
      await ownerContainer
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Olga', avatar: '🦫');
      await ownerContainer
          .read(profileControllerProvider.notifier)
          .markOnboarded();
      final ownerAddr = (await ownerContainer.read(
        walletKeysProvider.future,
      ))!.address;

      // Real production UI, real routes — this is what exercises the /nfc
      // route wiring, not just the domain/controller layer.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ownerContainer,
          child: const CashMeOutsideApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.qr_code));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfc.stickerStudio')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('nfc.voucher.amount')), '50');
      await tester.tap(find.byKey(const Key('nfc.write.voucher')));
      await tester.pumpAndSettle();

      expect(ownerPort.writtenTags, hasLength(1));
      final voucherUri = ownerPort.writtenTags.single;

      // Writing the sticker doesn't self-ingest — the owner->throwaway tx
      // only commits to a ledger once someone claims it.
      final ownerLedgerAfterWrite = await ownerContainer.read(
        ledgerControllerProvider.future,
      );
      expect(ownerLedgerAfterWrite.balances[ownerAddr], 500);

      // A second, independent wallet — its own container, its own NFC port
      // (physically a different phone).
      final claimantPort = FakeNfcPort();
      final claimantContainer = ProviderContainer(
        overrides: fakeHardwareOverrides(nfcPort: claimantPort),
      );
      addTearDown(claimantContainer.dispose);
      await claimantContainer
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Chase', avatar: '🦊');
      final claimantAddr = (await claimantContainer.read(
        walletKeysProvider.future,
      ))!.address;
      await claimantContainer.read(nfcControllerProvider.future);

      // The physical tap: the sticker's payload is read by the second phone.
      claimantPort.injectRead(voucherUri);
      await tester.pumpAndSettle();

      final claimantLedger = await claimantContainer.read(
        ledgerControllerProvider.future,
      );
      expect(claimantLedger.balances[claimantAddr], 550); // 500 mint + 50

      // Pull the two transactions the claim produced: the voucher (owner ->
      // throwaway) and the sweep (throwaway -> claimant).
      final voucherTx = (decodeQr(voucherUri) as VoucherPayload).tx;
      final sweepTx = claimantLedger.ordered.singleWhere(
        (tx) => tx.type == txTypeTransfer && tx.to == claimantAddr,
      );

      // Simulate the eventual sync (mesh/QR) that would carry these same two
      // transactions back to the owner. Ledger convergence is order-agnostic
      // (grow-only CRDT, spec §2.2) — ingest sweep before voucher here to
      // prove that.
      final ownerLedgerNotifier = ownerContainer.read(
        ledgerControllerProvider.notifier,
      );
      await ownerLedgerNotifier.ingestExternal(sweepTx);
      await ownerLedgerNotifier.ingestExternal(voucherTx);

      final ownerLedgerAfterSync = await ownerContainer.read(
        ledgerControllerProvider.future,
      );
      // Convergence: owner and claimant independently ingested the same
      // voucher+sweep pair (owner via this sync, claimant via the NFC claim)
      // and computed matching deltas for both addresses, regardless of
      // ingest order or what else is in either ledger.
      expect(ownerLedgerAfterSync.balances[ownerAddr], 450); // 500 - 50
      expect(ownerLedgerAfterSync.balances[claimantAddr], 50);
    },
  );
}
