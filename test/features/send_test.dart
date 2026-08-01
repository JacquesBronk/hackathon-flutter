import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/features/send/send_flow.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/nfc_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

late FakeQrScanner scanner;
late FakeBiometricGate gate;

Future<ProviderContainer> pumpSend(
  WidgetTester tester, {
  bool approve = true,
}) async {
  scanner = FakeQrScanner();
  gate = FakeBiometricGate(approve: approve);
  final overrides = fakeHardwareOverrides(scanner: scanner, gate: gate);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Me', avatar: '🦫');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SendFlow()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('scan rr → confirm (name + truncated addr) → biometric → tx QR', (
    tester,
  ) async {
    final container = await pumpSend(tester);
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    scanner.emit(
      encodeReceiveRequest(
        ReceiveRequest(addr: peer.address, name: 'Anna', amount: 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text(truncateAddr(peer.address)), findsOneWidget);
    await tester.tap(find.byKey(const Key('send.confirm')));
    await tester.pumpAndSettle();
    expect(gate.authCalls, 1);
    expect(find.byType(QrImageView), findsOneWidget);
    final state = await container.read(ledgerControllerProvider.future);
    // Send-at-signing: the SENDER's own replay already credits the peer's
    // address — the peer's device just hasn't ingested anything yet.
    expect(state.balances[peer.address], 120);
    await tester.tap(find.byKey(const Key('send.done')));
    await tester.pumpAndSettle();
  });

  testWidgets('biometric denial: no send, stays on confirm', (tester) async {
    final container = await pumpSend(tester, approve: false);
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    scanner.emit(
      encodeReceiveRequest(
        ReceiveRequest(addr: peer.address, name: 'Anna', amount: 120),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send.confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.ordered.length, 1); // only the mint
  });

  testWidgets('malformed QR: friendly error, still scanning', (tester) async {
    await pumpSend(tester);
    scanner.emit('definitely not a pinnie code');
    await tester.pumpAndSettle();
    expect(find.text('Not a pinnie code'), findsOneWidget);
  });

  testWidgets(
    'NFC tap (HCE rr read) routes to the same confirm phase as a QR scan',
    (tester) async {
      final nfcPort = FakeNfcPort();
      final container = ProviderContainer(
        overrides: fakeHardwareOverrides(nfcPort: nfcPort),
      );
      addTearDown(container.dispose);
      await container
          .read(profileControllerProvider.notifier)
          .createWallet(name: 'Me', avatar: '🦫');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SendFlow()),
        ),
      );
      await tester.pumpAndSettle();

      final peer = await WalletKeys.fromSeed(List.filled(32, 8));
      nfcPort.injectRead(
        encodeReceiveRequest(
          ReceiveRequest(addr: peer.address, name: 'Anna', amount: 120),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text(truncateAddr(peer.address)), findsOneWidget);
      expect(find.byKey(const Key('send.confirm')), findsOneWidget);
    },
  );
}
