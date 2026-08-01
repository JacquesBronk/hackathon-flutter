import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import '../ports/nfc_port.dart';

/// Thrown by [NfcAdapter.startHceSession]/[stopHceSession]. No maintained
/// Flutter plugin exposes Android host-card-emulation as of 2026-08 (see
/// task C3's report: nfc_host_card_emulation and flutter_nfc_hce are both
/// years-stale, nfc_pro_manager is an unverified low-adoption uploader).
/// Tap mode is device-pass-blocked until a maintained plugin lands or a
/// native HCE service is built; NTAG sticker read/write are unaffected.
class NfcHceUnavailableException implements Exception {
  const NfcHceUnavailableException();
  @override
  String toString() =>
      'HCE is unavailable: no maintained Flutter plugin exposes Android '
      'host-card-emulation as of 2026-08.';
}

// NFC Forum URI Record Type Definition: payload[0] is the "URI Identifier
// Code"; 0x00 means verbatim (no prefix abbreviation), required since
// `cmo:` isn't one of the standard well-known prefixes.
const _uriIdentifierCodeVerbatim = 0x00;
final _uriRecordType = Uint8List.fromList([0x55]); // 'U'

NdefRecord _uriRecord(String uri) => NdefRecord(
  typeNameFormat: TypeNameFormat.wellKnown,
  type: _uriRecordType,
  identifier: Uint8List(0),
  payload: Uint8List.fromList([
    _uriIdentifierCodeVerbatim,
    ...utf8.encode(uri),
  ]),
);

String? _decodeUriRecord(NdefMessage message) {
  for (final record in message.records) {
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        record.type.length == 1 &&
        record.type[0] == 0x55 &&
        record.payload.isNotEmpty &&
        record.payload[0] == _uriIdentifierCodeVerbatim) {
      return utf8.decode(record.payload.sublist(1));
    }
  }
  return null;
}

/// `nfc_manager` + `nfc_manager_ndef`-backed reader/writer — the only file
/// importing either plugin. Payloads are the app's existing `cmo:` URIs
/// wrapped in a single NDEF URI record. HCE is not implemented (see
/// [NfcHceUnavailableException]) — real hardware verification for reads and
/// writes is a human device-pass step (no NFC radio in this sandbox).
class NfcAdapter implements NfcPort {
  NfcAdapter() {
    _tagsRead.onListen = _resumeReadLoop;
    _tagsRead.onCancel = () => _readLoopWanted = false;
  }

  final _tagsRead = StreamController<String>.broadcast();
  bool _readLoopWanted = false;

  @override
  Stream<String> get tagsRead => _tagsRead.stream;

  void _resumeReadLoop() {
    _readLoopWanted = true;
    unawaited(_pollOnce());
  }

  Future<void> _pollOnce() async {
    if (!_readLoopWanted) return;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso14443},
        onDiscovered: (tag) async {
          final ndef = Ndef.from(tag);
          final message = ndef?.cachedMessage ?? await ndef?.read();
          final uri = message == null ? null : _decodeUriRecord(message);
          if (uri != null) _tagsRead.add(uri);
          await NfcManager.instance.stopSession();
          unawaited(_pollOnce());
        },
      );
    } catch (_) {
      // NFC off/unavailable — give up this attempt; the next tagsRead
      // subscriber (or app resume) retries via onListen.
    }
  }

  @override
  Future<void> writeTag(String uri) async {
    final wasReading = _readLoopWanted;
    _readLoopWanted = false;
    await NfcManager.instance.stopSession().catchError((_) {});
    await NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443},
      onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          await ndef.write(message: NdefMessage(records: [_uriRecord(uri)]));
        }
        await NfcManager.instance.stopSession();
      },
    );
    if (wasReading) _resumeReadLoop();
  }

  @override
  Future<void> startHceSession(String uri) async {
    throw const NfcHceUnavailableException();
  }

  @override
  Future<void> stopHceSession() async {
    throw const NfcHceUnavailableException();
  }
}
