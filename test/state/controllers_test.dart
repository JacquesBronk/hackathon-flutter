import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late InMemoryLedgerStore store;

  setUp(() {
    store = InMemoryLedgerStore();
    container = ProviderContainer(
      overrides: [
        ...fakeHardwareOverrides(),
        ledgerStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  test('createWallet mints 500 and persists profile + seed + tx', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Jacques', avatar: '🦫');
    final keys = (await container.read(walletKeysProvider.future))!;
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[keys.address], 500);
    expect((await store.loadAll()).single.type, txTypeMint);
    final profile = container.read(profileControllerProvider).value!;
    expect(profile.onboarded, isFalse); // true only after biometric step
  });

  test('send signs, debits, persists, bumps lamport', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'J', avatar: '🦫');
    final other = await WalletKeys.fromSeed(List.filled(32, 5));
    final tx = await container
        .read(ledgerControllerProvider.notifier)
        .send(to: other.address, amount: 700, memo: 'pizza');
    final state = await container.read(ledgerControllerProvider.future);
    final keys = (await container.read(walletKeysProvider.future))!;
    expect(state.balances[keys.address], -200); // never blocked by balance
    expect(tx.lamportTs, greaterThan(1));
    expect(await store.loadLamport(), tx.lamportTs);
    expect((await store.loadAll()).length, 2);
  });

  test('ingestExternal validates and is idempotent', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'J', avatar: '🦫');
    final keys = (await container.read(walletKeysProvider.future))!;
    final other = await WalletKeys.fromSeed(List.filled(32, 5));
    final incoming = await buildSigned(
      keys: other,
      to: keys.address,
      amount: 40,
      type: txTypeTransfer,
      lamportTs: 9,
    );
    final n = container.read(ledgerControllerProvider.notifier);
    expect((await n.ingestExternal(incoming)).status, IngestStatus.added);
    expect((await n.ingestExternal(incoming)).status, IngestStatus.duplicate);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[keys.address], 540);
  });
}
