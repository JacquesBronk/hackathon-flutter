import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/keys.dart';
import 'fakes/fakes.dart';
import 'ports/biometric_gate.dart';
import 'ports/key_vault.dart';
import 'ports/ledger_store.dart';
import 'ports/peer_directory.dart';
import 'ports/profile_store.dart';
import 'ports/qr_scanner.dart';
import 'state/ledger_controller.dart';
import 'state/profile_controller.dart';

export 'state/ledger_controller.dart' show LedgerController, LedgerState;
export 'state/profile_controller.dart' show ProfileController;
export 'ports/profile_store.dart' show Profile;

const presetAvatars = [
  '🦫',
  '🦜',
  '🐸',
  '🦊',
  '🐙',
  '🦔',
  '🐳',
  '🦩',
  '🐢',
  '🦉',
  '🦄',
  '🐝',
];

final keyVaultProvider = Provider<KeyVault>((_) => throw UnimplementedError());
final biometricGateProvider = Provider<BiometricGate>(
  (_) => throw UnimplementedError(),
);
final qrScannerProvider = Provider<QrScanner>(
  (_) => throw UnimplementedError(),
);
final ledgerStoreProvider = Provider<LedgerStore>(
  (_) => throw UnimplementedError(),
);
final profileStoreProvider = Provider<ProfileStore>(
  (_) => throw UnimplementedError(),
);
final peerDirectoryProvider = Provider<PeerDirectory>(
  (_) => throw UnimplementedError(),
);

/// null until a wallet exists (pre-onboarding).
final walletKeysProvider = FutureProvider<WalletKeys?>((ref) async {
  final seed = await ref.watch(keyVaultProvider).loadSeed();
  return seed == null ? null : WalletKeys.fromSeed(seed);
});

final ledgerControllerProvider =
    AsyncNotifierProvider<LedgerController, LedgerState>(LedgerController.new);
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

/// Full fake set for tests and FAKE_HARDWARE runs. Pass specific instances
/// when a test needs to drive them (emit scans, deny biometrics).
List<Override> fakeHardwareOverrides({
  FakeQrScanner? scanner,
  FakeBiometricGate? gate,
}) => [
  keyVaultProvider.overrideWithValue(InMemoryKeyVault()),
  biometricGateProvider.overrideWithValue(gate ?? FakeBiometricGate()),
  qrScannerProvider.overrideWithValue(scanner ?? FakeQrScanner()),
  ledgerStoreProvider.overrideWithValue(InMemoryLedgerStore()),
  profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
  peerDirectoryProvider.overrideWithValue(InMemoryPeerDirectory()),
];
