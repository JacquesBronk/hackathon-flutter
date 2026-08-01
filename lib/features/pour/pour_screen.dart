import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/keys.dart';
import '../../providers.dart';
import '../../state/grace_window.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';
import '../send/grace_window_widget.dart';

const _uuid = Uuid();
const _maxBurstParticles = 6;

enum _Phase { idle, pouring, grace, sending, done, cancelled }

/// Pour-to-pay sender screen (spec §3): tilting streams cosmetic `pour`
/// envelopes while [PourController] accumulates from tilt at 4Hz. Stopping
/// runs the biometric gate, then arms the shake-to-cancel grace window
/// (post-biometric, pre-sign — same order as the QR/mesh send flows); the
/// single signed tx money invariant lives in [PourController.finishPour] —
/// this screen never signs or sends anything itself.
class PourScreen extends ConsumerStatefulWidget {
  const PourScreen({
    super.key,
    required this.to,
    this.toName,
    this.ticker,
    this.graceWindow = const GraceWindow(),
  });

  final String to;
  final String? toName;

  /// Test-injectable 4Hz sample ticker, forwarded to
  /// [PourController.startPour]; production leaves this null so the
  /// controller falls back to a real periodic timer.
  final Stream<void>? ticker;

  /// Test-injectable — production uses the real (`Future.delayed`) window.
  /// Tests inject a [GraceWindow] with a controllable scheduler so neither
  /// path needs a real pending `Timer` (which fails widget tests).
  final GraceWindow graceWindow;

  @override
  ConsumerState<PourScreen> createState() => _PourScreenState();
}

class _PourScreenState extends ConsumerState<PourScreen> {
  _Phase _phase = _Phase.idle;
  int _burstSeq = 0;
  int _lastGain = 0;
  String? _pendingId;

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.pouring);
    await ref
        .read(pourControllerProvider.notifier)
        .startPour(to: widget.to, ticker: widget.ticker);
  }

  /// Stops accumulation (no money moved yet), runs the biometric gate, then
  /// arms the shake-to-cancel grace window (spec §3: post-biometric,
  /// pre-sign) — only once it elapses undisturbed does [_afterGrace] call
  /// [PourController.finishPour] for the one signed tx.
  Future<void> _stop() async {
    final controller = ref.read(pourControllerProvider.notifier);
    await controller.stopPour();
    if (!mounted) return;

    final approved = await controller.authenticate();
    if (!mounted) return;
    if (!approved) {
      setState(() => _phase = _Phase.idle);
      _showSnack('Biometric check failed');
      return;
    }

    setState(() {
      _pendingId = _uuid.v7();
      _phase = _Phase.grace;
    });
  }

  /// Fires once the post-biometric [GraceWindowWidget] decides: `true` =
  /// window elapsed undisturbed, so this is the ONE place a pour actually
  /// signs+sends a tx (spec Global Constraints — shake-cancel must abort
  /// before `finishPour()`, never after). `false` = aborted; nothing sent.
  Future<void> _afterGrace(bool decided) async {
    if (!decided) {
      setState(() => _phase = _Phase.cancelled);
      _showSnack('Pour cancelled — nothing sent');
      return;
    }
    setState(() => _phase = _Phase.sending);
    final sent = await ref.read(pourControllerProvider.notifier).finishPour();
    if (!mounted) return;
    setState(() => _phase = sent ? _Phase.done : _Phase.idle);
    if (!sent) _showSnack("Couldn't send — try again");
  }

  @override
  Widget build(BuildContext context) {
    final pourAsync = ref.watch(pourControllerProvider);
    ref.listen<AsyncValue<PourState>>(pourControllerProvider, (prev, next) {
      final before = prev?.valueOrNull?.outgoing?.pouredTotal ?? 0;
      final after = next.valueOrNull?.outgoing?.pouredTotal ?? 0;
      if (after > before) {
        setState(() {
          _lastGain = after - before;
          _burstSeq++;
        });
      }
    });

    if (!pourAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final poured = pourAsync.value!.outgoing?.pouredTotal ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Pour')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.toName == null
                  ? truncateAddr(widget.to)
                  : '${widget.toName} · ${truncateAddr(widget.to)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: _CoinBurst(key: ValueKey(_burstSeq), count: _lastGain),
            ),
            Text(
              'ᵽ$poured',
              key: const Key('pour.amount'),
              style: cmoAmountStyle(
                color: _phase == _Phase.done
                    ? CmoColors.green
                    : CmoColors.orange,
              ),
            ),
            const SizedBox(height: 32),
            _buildAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (_phase) {
      case _Phase.idle:
        return FilledButton(
          key: const Key('pour.start'),
          onPressed: _start,
          child: const Text('Tilt to pour'),
        );
      case _Phase.pouring:
        return FilledButton(
          key: const Key('pour.stop'),
          onPressed: _stop,
          child: const Text('Stop & send'),
        );
      case _Phase.grace:
        return GraceWindowWidget(
          pendingId: _pendingId!,
          graceWindow: widget.graceWindow,
          onDecided: (decided) => unawaited(_afterGrace(decided)),
        );
      case _Phase.sending:
        return const CircularProgressIndicator();
      case _Phase.done:
        return FilledButton(
          key: const Key('pour.done'),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Done'),
        );
      case _Phase.cancelled:
        return OutlinedButton(
          key: const Key('pour.start'),
          onPressed: _start,
          child: const Text('Pour again'),
        );
    }
  }
}

/// A single finite burst of falling coin dots — never loops, so
/// `pumpAndSettle` always terminates (same convention as [PinnieCoin]).
/// Re-keyed per burst by the parent so the old controller set is disposed
/// and a fresh one plays for the next tick's gain.
class _CoinBurst extends StatefulWidget {
  const _CoinBurst({super.key, required this.count});
  final int count;

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<_CoinBurst> with TickerProviderStateMixin {
  late final _controllers = List.generate(
    widget.count.clamp(0, _maxBurstParticles),
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward(),
  );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        for (var i = 0; i < _controllers.length; i++)
          AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, _) {
              final t = _controllers[i].value;
              return Positioned(
                top: t * 90,
                left: (i - _controllers.length / 2) * 14,
                child: Opacity(
                  opacity: 1 - t,
                  child: const Icon(
                    Icons.circle,
                    size: 12,
                    color: CmoColors.orange,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
