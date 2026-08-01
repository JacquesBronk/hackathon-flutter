import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/domain/voucher.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/fakes/nfc_fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Node {
  _Node(this.container, this.nfcPort, this.addr);
  final ProviderContainer container;
  final FakeNfcPort nfcPort;
  final String addr;

  NfcController get nfc => container.read(nfcControllerProvider.notifier);
}

Future<_Node> _createNode(
  List<ProviderContainer> registry,
  String name, {
  FakeBiometricGate? gate,
}) async {
  final nfcPort = FakeNfcPort();
  final container = ProviderContainer(
    overrides: fakeHardwareOverrides(nfcPort: nfcPort, gate: gate),
  );
  registry.add(container);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: name, avatar: '🦫');
  final keys = await container.read(walletKeysProvider.future);
  await container.read(nfcControllerProvider.future); // build + subscribe
  return _Node(container, nfcPort, keys!.address);
}

void main() {
  late List<ProviderContainer> containers;

  setUp(() => containers = []);
  tearDown(() {
    for (final c in containers) {
      c.dispose();
    }
  });

  test(
    'enableTapMode starts an HCE session carrying own rr1 request',
    () async {
      final node = await _createNode(containers, 'Jacques');
      await node.nfc.enableTapMode(amount: 30);

      expect(node.nfcPort.hceActive, isTrue);
      expect(node.nfcPort.hceSessions, hasLength(1));
      final rr = decodeQr(node.nfcPort.hceSessions.single) as ReceiveRequest;
      expect(rr.addr, node.addr);
      expect(rr.amount, 30);

      final state = await node.container.read(nfcControllerProvider.future);
      expect(state.tapModeActive, isTrue);
    },
  );

  test('disableTapMode stops the HCE session', () async {
    final node = await _createNode(containers, 'Anna');
    await node.nfc.enableTapMode();
    await node.nfc.disableTapMode();

    expect(node.nfcPort.hceActive, isFalse);
    final state = await node.container.read(nfcControllerProvider.future);
    expect(state.tapModeActive, isFalse);
  });

  test('writeRequestTag writes an rr1 tag for this wallet', () async {
    final node = await _createNode(containers, 'Beto');
    await node.nfc.writeRequestTag(amount: 12);

    expect(node.nfcPort.writtenTags, hasLength(1));
    final rr = decodeQr(node.nfcPort.writtenTags.single) as ReceiveRequest;
    expect(rr.addr, node.addr);
    expect(rr.amount, 12);
  });

  test(
    'reading an rr1 tag surfaces it on sendRequests, not the ledger',
    () async {
      final node = await _createNode(containers, 'Carol');
      final other = await WalletKeys.fromSeed(List.filled(32, 4));
      final events = <ReceiveRequest>[];
      final sub = node.nfc.sendRequests.listen(events.add);

      node.nfcPort.injectRead(
        encodeReceiveRequest(
          ReceiveRequest(addr: other.address, name: 'Dana', amount: 25),
        ),
      );
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.addr, other.address);
      final ledgerState = await node.container.read(
        ledgerControllerProvider.future,
      );
      expect(ledgerState.ordered, hasLength(1)); // only this node's own mint
      await sub.cancel();
    },
  );

  test('reading a tx1 tag ingests it into the ledger', () async {
    final node = await _createNode(containers, 'Dinesh');
    final other = await WalletKeys.fromSeed(List.filled(32, 5));
    final tx = await buildSigned(
      keys: other,
      to: node.addr,
      amount: 40,
      type: txTypeTransfer,
      lamportTs: 1,
    );
    node.nfcPort.injectRead(encodeTransaction(tx));
    await pumpEventQueue();

    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.balances[node.addr], 540); // 500 mint + 40
  });

  test(
    'reading a voucher tag claims it: sweep ingested, balance moves',
    () async {
      final owner = await WalletKeys.fromSeed(List.filled(32, 6));
      final ownerMint = await buildSigned(
        keys: owner,
        to: owner.address,
        amount: 500,
        type: txTypeMint,
        lamportTs: 1,
      );
      final (voucherUri, _) = await mintVoucher(
        owner: owner,
        amount: 75,
        lamportTs: 2,
      );

      final node = await _createNode(containers, 'Emma');
      // The claimant's own ledger must independently know the voucher tx is
      // legitimate — it validates the owner's signature itself, no shared
      // ledger needed. (Owner's own mint isn't relevant to the claimant's
      // local view; included here only to document the origin of funds.)
      expect(ownerMint.amount, 500);

      node.nfcPort.injectRead(voucherUri);
      await pumpEventQueue();

      final ledgerState = await node.container.read(
        ledgerControllerProvider.future,
      );
      expect(ledgerState.balances[node.addr], 575); // 500 mint + 75 claimed

      final state = await node.container.read(nfcControllerProvider.future);
      expect(state.lastClaimAmount, 75);
    },
  );

  test('a malformed tag read is dropped silently', () async {
    final node = await _createNode(containers, 'Farid');
    node.nfcPort.injectRead('not a pinnie code at all');
    await pumpEventQueue();

    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.ordered, hasLength(1)); // only the mint
  });

  test(
    'writeVoucherTag is biometric-gated: denied gate writes nothing',
    () async {
      final node = await _createNode(
        containers,
        'Gia',
        gate: FakeBiometricGate(approve: false),
      );
      final wrote = await node.nfc.writeVoucherTag(20);

      expect(wrote, isFalse);
      expect(node.nfcPort.writtenTags, isEmpty);
    },
  );

  test('writeVoucherTag mints and writes a v1 tag once approved', () async {
    final node = await _createNode(containers, 'Hugo');
    final wrote = await node.nfc.writeVoucherTag(20);

    expect(wrote, isTrue);
    expect(node.nfcPort.writtenTags, hasLength(1));
    final voucher = decodeQr(node.nfcPort.writtenTags.single) as VoucherPayload;
    expect(voucher.tx.from, node.addr);
    expect(voucher.tx.amount, 20);

    // Minting doesn't ingest locally — the tx is only committed on claim.
    final ledgerState = await node.container.read(
      ledgerControllerProvider.future,
    );
    expect(ledgerState.balances[node.addr], 500);
  });
}
