import 'dart:convert';
import 'dart:typed_data';
import 'package:cash_me_outside/adapters/ble_mesh_transport.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _frame(String json) {
  final body = utf8.encode(json);
  final out = Uint8List(4 + body.length)
    ..buffer.asByteData().setUint32(0, body.length)
    ..setRange(4, 4 + body.length, body);
  return out;
}

void main() {
  group('FrameReassembler', () {
    test('reassembles a frame delivered as a single chunk', () {
      final r = FrameReassembler();
      expect(r.addChunk(_frame('{"a":1}')), ['{"a":1}']);
    });

    test('reassembles a frame split across many small chunks', () {
      final r = FrameReassembler();
      final bytes = _frame('{"hello":"addr1","name":"Anna"}');
      final out = <String>[];
      for (final b in bytes) {
        out.addAll(r.addChunk([b])); // one byte at a time
      }
      expect(out, ['{"hello":"addr1","name":"Anna"}']);
    });

    test('emits multiple frames packed into one chunk', () {
      final r = FrameReassembler();
      final combined = [..._frame('{"a":1}'), ..._frame('{"b":2}')];
      expect(r.addChunk(combined), ['{"a":1}', '{"b":2}']);
    });

    test('carries a partial frame across addChunk calls', () {
      final r = FrameReassembler();
      final bytes = _frame('{"a":1}');
      final mid = bytes.length ~/ 2;
      expect(r.addChunk(bytes.sublist(0, mid)), isEmpty);
      expect(r.addChunk(bytes.sublist(mid)), ['{"a":1}']);
    });

    test('handles a length prefix split across chunks', () {
      final r = FrameReassembler();
      final bytes = _frame('{"a":1}');
      expect(
        r.addChunk(bytes.sublist(0, 2)),
        isEmpty,
      ); // half the length prefix
      expect(r.addChunk(bytes.sublist(2)), ['{"a":1}']);
    });

    test('reassembler is independent per instance', () {
      final r1 = FrameReassembler();
      final r2 = FrameReassembler();
      final bytes = _frame('{"x":true}');
      expect(r1.addChunk(bytes.sublist(0, 3)), isEmpty);
      expect(r2.addChunk(bytes), ['{"x":true}']);
      expect(r1.addChunk(bytes.sublist(3)), ['{"x":true}']);
    });
  });
}
