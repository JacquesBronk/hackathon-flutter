import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'adapters/ble_mesh_transport.dart';
import 'adapters/drift_db.dart';
import 'adapters/drift_outbox_store.dart';
import 'adapters/local_auth_gate.dart';
import 'adapters/local_notifier.dart';
import 'adapters/mobile_qr_scanner.dart';
import 'adapters/prefs_profile_store.dart';
import 'adapters/secure_key_vault.dart';
import 'domain/keys.dart';
import 'fakes/fakes.dart';
import 'fakes/mesh_fakes.dart';
import 'fakes/sensor_fakes.dart';
import 'ports/biometric_gate.dart';
import 'ports/haptics.dart';
import 'ports/key_vault.dart';
import 'ports/ledger_store.dart';
import 'ports/mesh_transport.dart';
import 'ports/motion_sensor.dart';
import 'ports/notifier.dart';
import 'ports/outbox_store.dart';
import 'ports/peer_directory.dart';
import 'ports/profile_store.dart';
import 'ports/qr_scanner.dart';
import 'ports/seen_store.dart';
import 'state/ledger_controller.dart';
import 'state/mesh_controller.dart';
import 'state/pour_controller.dart';
import 'state/profile_controller.dart';
import 'state/rain_controller.dart';

export 'state/ledger_controller.dart' show LedgerController, LedgerState;
export 'state/mesh_controller.dart'
    show MeshController, MeshState, MeshDeliveryStatus;
export 'state/pour_controller.dart'
    show PourController, PourState, PourSessionState, PourCatchState;
export 'state/profile_controller.dart' show ProfileController;
export 'state/rain_controller.dart' show RainController, RainState;
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
final motionSensorProvider = Provider<MotionSensor>(
  (_) => throw UnimplementedError(),
);
final hapticsProvider = Provider<Haptics>((_) => throw UnimplementedError());

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
final pourControllerProvider = AsyncNotifierProvider<PourController, PourState>(
  PourController.new,
);
final rainControllerProvider = AsyncNotifierProvider<RainController, RainState>(
  RainController.new,
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
  FakeMotionSensor? motionSensor,
  FakeHaptics? haptics,
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
  motionSensorProvider.overrideWithValue(motionSensor ?? FakeMotionSensor()),
  hapticsProvider.overrideWithValue(haptics ?? FakeHaptics()),
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
    // Lazily constructed on first read (inside MeshController.build(), which
    // only runs once a wallet exists — see app.dart's real-wiring bootstrap)
    // since BleMeshTransport needs the resolved wallet address/name up front.
    meshTransportProvider.overrideWith((ref) {
      final selfAddr = ref.read(walletKeysProvider).value!.address;
      final selfName = ref.read(profileControllerProvider).value?.name ?? '';
      return BleMeshTransport(selfAddr: selfAddr, selfName: selfName);
    }),
    notifierProvider.overrideWithValue(LocalNotifier()),
    outboxStoreProvider.overrideWithValue(DriftOutboxStore(db)),
    seenStoreProvider.overrideWithValue(DriftSeenStore(db)),
  ];
}
