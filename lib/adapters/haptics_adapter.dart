import 'package:flutter/services.dart';
import '../ports/haptics.dart';

class HapticsAdapter implements Haptics {
  @override
  Future<void> tick() => HapticFeedback.selectionClick();
}
