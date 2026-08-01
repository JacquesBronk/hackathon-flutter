import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' as periph;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../domain/keys.dart';
import '../ports/mesh_transport.dart';

/// 16-bit Bluetooth service UUID for the mesh (spec §2.3), base-expanded to
/// the standard 128-bit form by both plugins.
const meshServiceUuid16 = 0xca5e;

/// The mesh's single write/notify characteristic. Not a registered SIG
/// UUID — arbitrary, adjacent to the service UUID for readability.
const meshCharacteristicUuid16 = 0xca5f;

const _requestedMtu = 512;
// BLE's mandatory minimum ATT MTU — the floor when negotiation is
// unsupported or the remote doesn't honor the request.
const _fallbackMtu = 23;
const _attHeaderOverhead = 3;

Uint8List _lengthPrefixedFrame(String frameJson) {
  final body = utf8.encode(frameJson);
  final out = Uint8List(4 + body.length)
    ..buffer.asByteData().setUint32(0, body.length)
    ..setRange(4, 4 + body.length, body);
  return out;
}

/// Reassembles whole frame JSON strings from a stream of raw byte chunks
/// using an internal 4-byte big-endian length prefix (spec §2.3: "chunking
/// is adapter-internal"). Pure logic, no BLE dependency — headlessly
/// testable independent of the rest of the adapter.
class FrameReassembler {
  final _buffer = BytesBuilder();
  int? _expectedLength;

  /// Feeds a raw chunk of bytes off the wire; returns the whole frames (if
  /// any) that completed as a result — zero, one, or several if multiple
  /// frames arrived back-to-back in the same or prior chunks.
  List<String> addChunk(List<int> chunk) {
    _buffer.add(chunk);
    final completed = <String>[];
    while (true) {
      final bytes = _buffer.toBytes();
      var expected = _expectedLength;
      if (expected == null) {
        if (bytes.length < 4) break;
        expected = ByteData.sublistView(bytes, 0, 4).getUint32(0);
        _expectedLength = expected;
      }
      final total = 4 + expected;
      if (bytes.length < total) break;
      completed.add(utf8.decode(bytes.sublist(4, total)));
      _buffer.clear();
      _buffer.add(bytes.sublist(total));
      _expectedLength = null;
    }
    return completed;
  }
}

String _encodeHello(String addr, String name) =>
    jsonEncode({'hello': addr, 'name': name});

({String addr, String name})? _tryDecodeHello(String frameJson) {
  try {
    final decoded = jsonDecode(frameJson);
    if (decoded is Map && decoded['hello'] is String) {
      return (
        addr: decoded['hello'] as String,
        name: (decoded['name'] as String?) ?? '',
      );
    }
  } catch (_) {
    // not JSON / not a hello frame
  }
  return null;
}

Uint8List _truncatedWalletId(String addr) {
  final raw = b64uDecode(addr);
  return Uint8List.sublistView(raw, 0, raw.length < 8 ? raw.length : 8);
}

/// BLE transport: `flutter_blue_plus` for the central role (scan + connect
/// out) and `bluetooth_low_energy` for the peripheral role (advertise + GATT
/// server), dual-role simultaneously so any two phones can gossip regardless
/// of which one initiates the connection. The only file importing either
/// plugin. No headless test possible beyond construction (no BLE radio in
/// this sandbox) — see the task report's device-verification checklist.
class BleMeshTransport implements MeshTransport {
  BleMeshTransport({required this.selfAddr, required this.selfName});

  final String selfAddr;
  final String selfName;

  final _peripheralManager = periph.PeripheralManager();
  final _peerEvents = StreamController<MeshPeer>.broadcast();
  final _peerLost = StreamController<String>.broadcast();
  final _inboundFrames = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  // Keyed by a per-connection id ('c:<remoteId>' for links we dialed out as
  // central, 'p:<central-uuid>' for links dialed into us as peripheral).
  final _senders = <String, Future<void> Function(Uint8List)>{};
  final _reassemblers = <String, FrameReassembler>{};
  // hello-resolved wallet addr per link, so later scan RSSI updates for an
  // already-identified central-role peer can re-emit MeshPeer with a fresh
  // rssi (spec §2.3: "rssi refreshes re-emit").
  final _addrByKey = <String, String>{};

  periph.GATTCharacteristic? _localCharacteristic;

  static final _serviceUuidFbp = fbp.Guid('CA5E');
  static final _characteristicUuidFbp = fbp.Guid('CA5F');
  static final _serviceUuidBle = periph.UUID.short(meshServiceUuid16);
  static final _characteristicUuidBle = periph.UUID.short(
    meshCharacteristicUuid16,
  );

  @override
  Stream<MeshPeer> get peerEvents => _peerEvents.stream;
  @override
  Stream<String> get peerLost => _peerLost.stream;
  @override
  Stream<String> get inboundFrames => _inboundFrames.stream;

  @override
  Future<void> start() async {
    await _startPeripheral();
    await _startCentral();
  }

  @override
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await fbp.FlutterBluePlus.stopScan();
    await _peripheralManager.stopAdvertising();
    await _peripheralManager.removeAllServices();
    _senders.clear();
    _reassemblers.clear();
  }

  @override
  Future<void> broadcastFrame(String frameJson) async {
    final bytes = _lengthPrefixedFrame(frameJson);
    for (final send in _senders.values.toList()) {
      unawaited(send(bytes));
    }
  }

  // --- Peripheral role: advertise + GATT server -----------------------

  Future<void> _startPeripheral() async {
    final characteristic = periph.GATTCharacteristic.mutable(
      uuid: _characteristicUuidBle,
      properties: const [
        periph.GATTCharacteristicProperty.write,
        periph.GATTCharacteristicProperty.writeWithoutResponse,
        periph.GATTCharacteristicProperty.notify,
      ],
      permissions: const [periph.GATTCharacteristicPermission.write],
      descriptors: const [],
    );
    _localCharacteristic = characteristic;
    final service = periph.GATTService(
      uuid: _serviceUuidBle,
      isPrimary: true,
      includedServices: const [],
      characteristics: [characteristic],
    );
    await _peripheralManager.removeAllServices();
    await _peripheralManager.addService(service);

    _subs.add(
      _peripheralManager.characteristicWriteRequested.listen(
        (event) => unawaited(_onPeripheralWrite(event)),
      ),
    );
    _subs.add(
      _peripheralManager.connectionStateChanged.listen((event) {
        if (event.state == periph.ConnectionState.disconnected) {
          _forgetLink(_peripheralKey(event.central));
        }
      }),
    );

    await _peripheralManager.startAdvertising(
      periph.Advertisement(
        name: selfName.isEmpty ? null : selfName,
        serviceUUIDs: [_serviceUuidBle],
        manufacturerSpecificData: [
          periph.ManufacturerSpecificData(
            id: meshServiceUuid16,
            data: _truncatedWalletId(selfAddr),
          ),
        ],
      ),
    );
  }

  String _peripheralKey(periph.Central central) => 'p:${central.uuid}';

  Future<void> _onPeripheralWrite(
    periph.GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final key = _peripheralKey(event.central);
    _onBytes(key, event.request.value);
    if (!_senders.containsKey(key)) {
      final characteristic = _localCharacteristic;
      if (characteristic != null) {
        final maxLen = await _peripheralManager.getMaximumNotifyLength(
          event.central,
        );
        final chunkSize = (maxLen - _attHeaderOverhead).clamp(1, _requestedMtu);
        _senders[key] = (bytes) =>
            _notifyChunked(event.central, characteristic, bytes, chunkSize);
        unawaited(_sendHello(key));
      }
    }
    await _peripheralManager.respondWriteRequest(event.request);
  }

  Future<void> _notifyChunked(
    periph.Central central,
    periph.GATTCharacteristic characteristic,
    Uint8List bytes,
    int chunkSize,
  ) async {
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      await _peripheralManager.notifyCharacteristic(
        central,
        characteristic,
        value: Uint8List.sublistView(bytes, offset, end),
      );
    }
  }

  // --- Central role: scan + connect out --------------------------------

  Future<void> _startCentral() async {
    _subs.add(
      fbp.FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          unawaited(_maybeConnect(r.device));
          final addr = _addrByKey[_centralKey(r.device)];
          if (addr != null) {
            _peerEvents.add(
              MeshPeer(
                addr: addr,
                name: null,
                rssi: r.rssi,
                lastSeen: DateTime.now(),
              ),
            );
          }
        }
      }),
    );
    await fbp.FlutterBluePlus.startScan(
      withServices: [_serviceUuidFbp],
      continuousUpdates: true,
    );
  }

  String _centralKey(fbp.BluetoothDevice device) => 'c:${device.remoteId}';

  Future<void> _maybeConnect(fbp.BluetoothDevice device) async {
    final key = _centralKey(device);
    if (_senders.containsKey(key)) return; // already connecting/connected
    _senders[key] = (_) async {}; // reserve the slot against re-entry
    try {
      // flutter_blue_plus >=2.x requires declaring a usage license at
      // connect time; this is a non-commercial demo app.
      await device.connect(license: fbp.License.nonprofit);
      _subs.add(
        device.connectionState.listen((s) {
          if (s == fbp.BluetoothConnectionState.disconnected) {
            _forgetLink(key);
          }
        }),
      );
      final chunkSize = await _negotiateChunkSize(device);
      final services = await device.discoverServices();
      fbp.BluetoothCharacteristic? characteristic;
      for (final s in services) {
        if (s.uuid != _serviceUuidFbp) continue;
        for (final c in s.characteristics) {
          if (c.uuid == _characteristicUuidFbp) characteristic = c;
        }
      }
      if (characteristic == null) {
        _forgetLink(key);
        return;
      }
      final chr = characteristic;
      _senders[key] = (bytes) => _writeChunked(chr, bytes, chunkSize);
      _subs.add(chr.lastValueStream.listen((value) => _onBytes(key, value)));
      await chr.setNotifyValue(true);
      await _sendHello(key);
    } catch (_) {
      _forgetLink(key);
    }
  }

  Future<int> _negotiateChunkSize(fbp.BluetoothDevice device) async {
    try {
      final mtu = await device.requestMtu(_requestedMtu);
      return (mtu - _attHeaderOverhead).clamp(1, _requestedMtu);
    } catch (_) {
      return _fallbackMtu - _attHeaderOverhead;
    }
  }

  Future<void> _writeChunked(
    fbp.BluetoothCharacteristic characteristic,
    Uint8List bytes,
    int chunkSize,
  ) async {
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      await characteristic.write(
        bytes.sublist(offset, end),
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
    }
  }

  // --- Shared: hello handshake, reassembly, peer mapping ----------------

  Future<void> _sendHello(String key) async {
    final send = _senders[key];
    if (send == null) return;
    await send(_lengthPrefixedFrame(_encodeHello(selfAddr, selfName)));
  }

  void _onBytes(String key, List<int> bytes) {
    final reassembler = _reassemblers.putIfAbsent(key, FrameReassembler.new);
    for (final frame in reassembler.addChunk(bytes)) {
      _onFrame(key, frame);
    }
  }

  void _onFrame(String key, String frameJson) {
    final hello = _tryDecodeHello(frameJson);
    if (hello != null) {
      _addrByKey[key] = hello.addr;
      _peerEvents.add(
        MeshPeer(
          addr: hello.addr,
          name: hello.name.isEmpty ? null : hello.name,
          rssi: 0,
          lastSeen: DateTime.now(),
        ),
      );
      return;
    }
    _inboundFrames.add(frameJson);
  }

  void _forgetLink(String key) {
    _senders.remove(key);
    _reassemblers.remove(key);
    final addr = _addrByKey.remove(key);
    if (addr != null) _peerLost.add(addr);
  }
}
