import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../domain/canonical.dart';
import '../domain/transaction.dart';
import '../ports/biometric_gate.dart';
import '../ports/key_vault.dart';
import '../ports/ledger_store.dart';
import '../ports/peer_directory.dart';
import '../ports/profile_store.dart';
import '../ports/qr_scanner.dart';

export '../ports/profile_store.dart' show Profile;

class InMemoryKeyVault implements KeyVault {
  Uint8List? _seed;
  @override
  Future<Uint8List?> loadSeed() async => _seed;
  @override
  Future<void> storeSeed(Uint8List seed32) async => _seed = seed32;
}

class FakeBiometricGate implements BiometricGate {
  FakeBiometricGate(
      {this.approve = true, this.available = true, this.delay = Duration.zero});
  final bool approve;
  final bool available;
  final Duration delay; // Duration.zero default: pending Timers fail widget tests
  int authCalls = 0;
  @override
  Future<bool> get isAvailable async => available;
  @override
  Future<bool> authenticate(String reason) async {
    authCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return approve;
  }
}

class FakeQrScanner implements QrScanner {
  final _controller = StreamController<String>.broadcast();
  @override
  Stream<String> get scans => _controller.stream;
  void emit(String payload) => _controller.add(payload);
  @override
  Widget buildPreview() => Container(
      color: const Color(0xFF222222),
      alignment: Alignment.center,
      child: const Text('camera preview (fake)',
          style: TextStyle(color: Color(0xFFFFFFFF))));
}

class InMemoryLedgerStore implements LedgerStore {
  // Keyed like the drift store (upsert semantics) — fake/adapter parity.
  final Map<String, Transaction> _txs = {};
  int _lamport = 0;
  @override
  Future<List<Transaction>> loadAll() async => _txs.values.toList();
  @override
  Future<void> save(Transaction tx) async => _txs[ledgerKeyOf(tx)] = tx;
  @override
  Future<int> loadLamport() async => _lamport;
  @override
  Future<void> saveLamport(int value) async => _lamport = value;
}

class InMemoryProfileStore implements ProfileStore {
  Profile? _profile;
  @override
  Future<Profile?> load() async => _profile;
  @override
  Future<void> save(Profile profile) async => _profile = profile;
}

class InMemoryPeerDirectory implements PeerDirectory {
  final _names = <String, String>{};
  @override
  Future<void> record(String addr, String name) async => _names[addr] = name;
  @override
  Future<String?> nameFor(String addr) async => _names[addr];
}
