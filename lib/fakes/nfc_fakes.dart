import 'dart:async';
import '../ports/nfc_port.dart';

/// Programmable fake NFC port. Reads are injected via [injectRead]; writes
/// and HCE session lifecycle are recorded for assertions.
class FakeNfcPort implements NfcPort {
  final List<String> writtenTags = [];
  final List<String> hceSessions = []; // each started session's URI
  bool hceActive = false;

  final _tagsRead = StreamController<String>.broadcast();
  @override
  Stream<String> get tagsRead => _tagsRead.stream;

  @override
  Future<void> writeTag(String uri) async => writtenTags.add(uri);

  @override
  Future<void> startHceSession(String uri) async {
    hceActive = true;
    hceSessions.add(uri);
  }

  @override
  Future<void> stopHceSession() async => hceActive = false;

  /// Test-only: simulate a tag read (or an incoming HCE tap).
  void injectRead(String uri) => _tagsRead.add(uri);
}
