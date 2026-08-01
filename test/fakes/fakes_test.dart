import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  test('InMemoryKeyVault round trips a seed', () async {
    final v = InMemoryKeyVault();
    expect(await v.loadSeed(), isNull);
    await v.storeSeed(Uint8List.fromList(List.filled(32, 9)));
    expect((await v.loadSeed())!.length, 32);
  });

  test('FakeBiometricGate approve/deny, zero delay by default', () async {
    expect(await FakeBiometricGate().authenticate('r'), isTrue);
    expect(await FakeBiometricGate(approve: false).authenticate('r'), isFalse);
    expect(await FakeBiometricGate(available: false).isAvailable, isFalse);
  });

  test('FakeQrScanner emits into scans stream', () async {
    final s = FakeQrScanner();
    final got = <String>[];
    final sub = s.scans.listen(got.add);
    s.emit('cmo:rr1:abc');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['cmo:rr1:abc']);
    await sub.cancel();
  });

  test('InMemoryProfileStore + InMemoryPeerDirectory round trip', () async {
    final p = InMemoryProfileStore();
    await p.save(const Profile(name: 'J', avatar: '🦫', onboarded: true));
    expect((await p.load())!.onboarded, isTrue);
    final d = InMemoryPeerDirectory();
    await d.record('addr1', 'Anna');
    expect(await d.nameFor('addr1'), 'Anna');
    expect(await d.nameFor('nope'), isNull);
  });
}
