import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

import '../../providers.dart';
import '../../state/grace_window.dart';
import '../../theme/tokens.dart';

/// Reusable post-biometric, pre-sign cancellation window (spec §3): a
/// countdown ring runs for [window] (default 5s) before the caller's send
/// actually signs; a shake — or, for accessibility/reduced-motion, the
/// cancel button — aborts it. Built standalone in B4; NOT yet wired into
/// the QR/mesh send confirm screens (B5 wires it there, around the sign
/// step). [onDecided] fires exactly once: `true` = window elapsed
/// undisturbed (caller may sign), `false` = aborted (caller must not sign).
class GraceWindowWidget extends ConsumerStatefulWidget {
  const GraceWindowWidget({
    super.key,
    required this.pendingId,
    required this.onDecided,
    this.window = const Duration(seconds: 5),
    this.abortSignal,
    this.graceWindow,
  });

  /// Identifies the pending send this window guards — feeds the widget key
  /// (`send.grace.<pendingId>`) so multiple confirm screens can coexist.
  final String pendingId;

  final ValueChanged<bool> onDecided;
  final Duration window;

  /// Shake source; defaults to [motionSensorProvider]'s shakes stream.
  /// Overridable so callers/tests can drive aborts without real hardware.
  final Stream<void>? abortSignal;

  /// Defaults to a real [GraceWindow]; overridable for deterministic tests.
  final GraceWindow? graceWindow;

  @override
  ConsumerState<GraceWindowWidget> createState() => _GraceWindowWidgetState();
}

class _GraceWindowWidgetState extends ConsumerState<GraceWindowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;
  final _combinedAbort = StreamController<void>.broadcast();
  StreamSubscription<void>? _externalAbortSub;
  bool _decided = false;
  bool _startedRing = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: widget.window);
    final external = widget.abortSignal ?? ref.read(motionSensorProvider).shakes;
    _externalAbortSub = external.listen((_) => _combinedAbort.add(null));
    unawaited(_run());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedRing) {
      _startedRing = true;
      if (!MediaQuery.of(context).disableAnimations) _ring.forward();
    }
  }

  Future<void> _run() async {
    final gw = widget.graceWindow ?? const GraceWindow();
    final completed = await gw.run(
      window: widget.window,
      abortSignal: _combinedAbort.stream,
    );
    _decide(completed);
  }

  void _cancelTapped() => _combinedAbort.add(null);

  void _decide(bool completed) {
    if (!mounted || _decided) return;
    _decided = true;
    if (!completed) {
      _ring.stop();
      unawaited(ref.read(hapticsProvider).tick());
    }
    widget.onDecided(completed);
  }

  @override
  void dispose() {
    unawaited(_externalAbortSub?.cancel());
    unawaited(_combinedAbort.close());
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      key: Key('send.grace.${widget.pendingId}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: reducedMotion
              ? const Icon(Icons.timer_outlined, size: 40)
              : AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) =>
                      CustomPaint(painter: _RingPainter(progress: _ring.value)),
                ),
        ),
        const SizedBox(height: 12),
        Text('Sending… shake to cancel', style: cmoMoneyStyle()),
        const SizedBox(height: 4),
        TextButton(
          key: Key('send.grace.cancel.${widget.pendingId}'),
          onPressed: _cancelTapped,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Countdown ring: [progress] 0..1 is elapsed fraction — the arc drawn is
/// the REMAINING time, sweeping back to nothing as the window elapses.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = CmoColors.navy.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, track);

    final remaining = (1 - progress).clamp(0.0, 1.0);
    if (remaining <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = CmoColors.orange;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * remaining,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
