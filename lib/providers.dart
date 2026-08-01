import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'adapters/drift_db.dart';
import 'adapters/local_auth_gate.dart';
import 'adapters/mobile_qr_scanner.dart';
import 'adapters/prefs_profile_store.dart';
import 'adapters/secure_key_vault.dart';
import 'domain/keys.dart';
import 'fakes/fakes.dart';
import 'fakes/mesh_fakes.dart';
import 'ports/biometric_gate.dart';
import 'ports/key_vault.dart';
import 'ports/ledger_store.dart';
import 'ports/mesh_transport.dart';
import 'ports/notifier.dart';
import 'ports/outbox_store.dart';
import 'ports/peer_directory.dart';
import 'ports/profile_store.dart';
import 'ports/qr_scanner.dart';
import 'ports/seen_store.dart';
import 'state/ledger_controller.dart';
import 'state/mesh_controller.dart';
import 'state/profile_controller.dart';

export 'state/ledger_controller.dart' show LedgerController, LedgerState;
export 'state/mesh_controller.dart'
    show MeshController, MeshState, MeshDeliveryStatus;
export 'state/profile_controller.dart' show ProfileController;
export 'ports/profile_store.dart' show Profile;
export 'ports/mesh_transport.dart' show MeshPeer;

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
final meshTransportProvider = Provider<MeshTransport>(
  (_) => throw UnimplementedError(),
);
final notifierProvider = Provider<Notifier>((_) => throw UnimplementedError());
final outboxStoreProvider = Provider<OutboxStore>(
  (_) => throw UnimplementedError(),
);
final seenStoreProvider = Provider<SeenStore>(
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
final meshControllerProvider = AsyncNotifierProvider<MeshController, MeshState>(
  MeshController.new,
);

/// Full fake set for tests and FAKE_HARDWARE runs. Pass specific instances
/// when a test needs to drive them (emit scans, deny biometrics, inject
/// mesh frames/peers).
List<Override> fakeHardwareOverrides({
  FakeQrScanner? scanner,
  FakeBiometricGate? gate,
  FakeMeshTransport? meshTransport,
  FakeNotifier? notifier,
  InMemoryOutboxStore? outboxStore,
  InMemorySeenStore? seenStore,
}) => [
  keyVaultProvider.overrideWithValue(InMemoryKeyVault()),
  biometricGateProvider.overrideWithValue(gate ?? FakeBiometricGate()),
  qrScannerProvider.overrideWithValue(scanner ?? FakeQrScanner()),
  ledgerStoreProvider.overrideWithValue(InMemoryLedgerStore()),
  profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
  peerDirectoryProvider.overrideWithValue(InMemoryPeerDirectory()),
  meshTransportProvider.overrideWithValue(meshTransport ?? FakeMeshTransport()),
  notifierProvider.overrideWithValue(notifier ?? FakeNotifier()),
  outboxStoreProvider.overrideWithValue(outboxStore ?? InMemoryOutboxStore()),
  seenStoreProvider.overrideWithValue(seenStore ?? InMemorySeenStore()),
];

/// Full real-hardware set for on-device runs (`FAKE_HARDWARE=false`).
List<Override> realHardwareOverrides() {
  final db = openAppDatabase();
  return [
    keyVaultProvider.overrideWithValue(SecureKeyVault()),
    biometricGateProvider.overrideWithValue(LocalAuthGate()),
    qrScannerProvider.overrideWithValue(MobileQrScanner()),
    ledgerStoreProvider.overrideWithValue(DriftLedgerStore(db)),
    profileStoreProvider.overrideWithValue(PrefsProfileStore()),
    peerDirectoryProvider.overrideWithValue(DriftPeerDirectory(db)),
  ];
}
