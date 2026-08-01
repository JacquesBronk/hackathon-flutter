import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

import '../../domain/canonical.dart';
import '../../domain/keys.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';

/// Make-it-rain (spec §3): amount split randomly across every currently-live
/// mesh peer, one signed tx per recipient behind a single biometric prompt
/// (`RainController.makeItRain`). Shake or the `rain.trigger` button (its
/// accessibility/reduced-motion equivalent — shake alone is not a reliable
/// input for everyone) both fire the same send path.
class RainScreen extends ConsumerStatefulWidget {
  const RainScreen({super.key, this.shakes});

  /// Overrides [motionSensorProvider]'s shakes stream — test injection point.
  final Stream<void>? shakes;

  @override
  ConsumerState<RainScreen> createState() => _RainScreenState();
}

class _RainScreenState extends ConsumerState<RainScreen>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  late final AnimationController _confetti;
  StreamSubscription<void>? _shakeSub;
  bool _sending = false;
  bool _reducedMotion = false;
  List<String>? _sentRecipients;
  Map<String, int>? _sentAmounts; // addr -> share, once sent

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final shakeStream = widget.shakes ?? ref.read(motionSensorProvider).shakes;
    _shakeSub = shakeStream.listen((_) => _trigger());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    unawaited(_shakeSub?.cancel());
    _confetti.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _trigger() async {
    if (_sending) return;
    final peers =
        ref.read(meshControllerProvider).valueOrNull?.livePeers ?? const [];
    if (peers.isEmpty) return;
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount < 1 || amount > maxAmount) {
      _showSnack("That's not a real amount of pinnies");
      return;
    }
    if (amount < peers.length) {
      _showSnack(
        'Not enough pinnies for ${peers.length} phones — everyone needs at '
        'least ᵽ1',
      );
      return;
    }
    setState(() => _sending = true);
    final recipients = peers.map((p) => p.addr).toList();
    try {
      final txIds = await ref
          .read(rainControllerProvider.notifier)
          .makeItRain(total: amount, recipients: recipients);
      if (!mounted) return;
      if (txIds == null) {
        setState(() => _sending = false);
        _showSnack('Biometric check failed');
        return;
      }
      final txById = {
        for (final tx in ref.read(ledgerControllerProvider).valueOrNull?.ordered ?? const [])
          tx.id: tx,
      };
      final amounts = <String, int>{};
      for (var i = 0; i < recipients.length; i++) {
        final tx = txById[txIds[i]];
        if (tx != null) amounts[recipients[i]] = tx.amount;
      }
      setState(() {
        _sending = false;
        _sentRecipients = recipients;
        _sentAmounts = amounts;
      });
      if (!_reducedMotion) _confetti.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnack("Couldn't send — try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final peers =
        ref.watch(meshControllerProvider).valueOrNull?.livePeers ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Make it rain')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: peers.isEmpty
            ? const Center(
                child: Text(
                  'No phones nearby yet — move closer to a crowd!',
                  textAlign: TextAlign.center,
                ),
              )
            : _buildEntry(peers.length),
      ),
    );
  }

  Widget _buildEntry(int peerCount) {
    final sentRecipients = _sentRecipients;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$peerCount phones nearby',
            textAlign: TextAlign.center,
            style: cmoMoneyStyle(size: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('rain.amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            enabled: !_sending,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 16),
          Text(
            'Shake your phone to make it rain',
            key: const Key('rain.shake.hint'),
            textAlign: TextAlign.center,
            style: cmoMoneyStyle(size: 13, color: CmoColors.navy),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('rain.trigger'),
            onPressed: _sending ? null : _trigger,
            child: Text(_sending ? 'Sending…' : 'Make it rain'),
          ),
          if (sentRecipients != null) ...[
            const SizedBox(height: 24),
            if (!_reducedMotion)
              SizedBox(
                height: 64,
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) =>
                      CustomPaint(painter: _ConfettiPainter(_confetti.value)),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'It rained on ${sentRecipients.length} phones!',
              textAlign: TextAlign.center,
              style: cmoMoneyStyle(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final addr in sentRecipients)
              Padding(
                key: Key('rain.sent.$addr'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'ᵽ${_sentAmounts?[addr] ?? '?'} → ${truncateAddr(addr)}',
                  textAlign: TextAlign.center,
                  style: cmoMoneyStyle(size: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

const _confettiColors = [CmoColors.orange, CmoColors.brass, CmoColors.green];

/// Finite confetti burst — [progress] 0..1 drives a single downward drift +
/// fade, never repeats (so pumpAndSettle always terminates).
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 12;
    for (var i = 0; i < count; i++) {
      final dx = size.width * (i + 0.5) / count;
      final dy = size.height * progress;
      final paint = Paint()
        ..color = _confettiColors[i % _confettiColors.length].withValues(
          alpha: (1 - progress).clamp(0.0, 1.0),
        );
      canvas.drawCircle(Offset(dx, dy), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
