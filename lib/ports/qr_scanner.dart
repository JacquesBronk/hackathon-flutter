import 'package:flutter/widgets.dart';

abstract interface class QrScanner {
  Stream<String> get scans;
  Widget buildPreview(); // UI never imports the scanner plugin directly
}
