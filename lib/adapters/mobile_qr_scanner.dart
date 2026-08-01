import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../ports/qr_scanner.dart';

class MobileQrScanner implements QrScanner {
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get scans => _controller.stream;

  @override
  Widget buildPreview() => MobileScanner(
    onDetect: (capture) {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null) _controller.add(raw);
      }
    },
  );
}
