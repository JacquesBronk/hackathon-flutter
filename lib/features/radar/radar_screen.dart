import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

import '../../domain/keys.dart';
import '../../domain/mesh/gossip_engine.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';

const _blipSize = 48.0;
const _innerRingFrac = 0.3;
const _midRingFrac = 0.6;
const _outerRingFrac = 0.9;

/// >-60 dBm = close, -60..-80 = mid, else far (spec §2.4 RSSI buckets).
double _ringFractionFor(int rssi) {
  if (rssi > -60) return _innerRingFrac;
  if (rssi >= -80) return _midRingFrac;
  return _outerRingFrac;
}

double _angleFor(String addr) =>
    (addr.hashCode & 0xffff) / 0xffff * 2 * math.pi;

Offset _positionFor(MeshPeer peer, Offset center, double maxRadius) {
  final radius = _ringFractionFor(peer.rssi) * maxRadius;
  final angle = _angleFor(peer.addr);
  return center + Offset(math.cos(angle), math.sin(angle)) * radius;
}

/// Radar screen (spec §2.4): self at center, live mesh peers as blips ringed
/// by RSSI bucket, a single-run pulse on relay traffic. Tests pump this
/// widget directly (no route is registered here — see A6).
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key, this.relayEvents});

  /// Fires once per envelope this phone relays for someone else. Optional so
  /// the widget is testable/constructible before the real wiring (A6) hooks
  /// it up to `MeshController`.
  final Stream<RelayEvent>? relayEvents;

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen>
    with SingleTickerProviderStateMixin {
  // Single-run pulse, re-triggered via forward(from: 0) — never repeats, so
  // pumpAndSettle always terminates (see theme/coin.dart for the same
  // pattern). Constructed eagerly in initState — as a lazy `late final`
  // field it would only be built on first access, which (in the reduced-
  // motion path, where build() never touches it) can end up being dispose(),
  // i.e. after the widget is unmounted, crashing the vsync ancestor lookup.
  late final AnimationController _pulse;
  StreamSubscription<RelayEvent>? _relaySub;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _relaySub = widget.relayEvents?.listen((_) {
      if (!_reducedMotion) _pulse.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    unawaited(_relaySub?.cancel());
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshControllerProvider).valueOrNull;
    final peers = meshState?.livePeers ?? const <MeshPeer>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Radar')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final center = size.center(Offset.zero);
          final maxRadius = size.shortestSide / 2 - _blipSize;
          return Stack(
            children: [
              Positioned.fill(
                child: _reducedMotion
                    ? CustomPaint(
                        painter: _RadarPainter(
                          center: center,
                          maxRadius: maxRadius,
                          pulseValue: 0,
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _RadarPainter(
                            center: center,
                            maxRadius: maxRadius,
                            pulseValue: _pulse.value,
                          ),
                        ),
                      ),
              ),
              for (final peer in peers)
                _Blip(
                  peer: peer,
                  position: _positionFor(peer, center, maxRadius),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/send-mesh',
                    arguments: peer.addr,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

const _blipColumnWidth = 88.0;

class _Blip extends StatelessWidget {
  const _Blip({
    required this.peer,
    required this.position,
    required this.onTap,
  });

  final MeshPeer peer;
  final Offset position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // name is unauthenticated — always paired with the truncated address
    // (skeleton display rule, spec §2.1).
    final label = peer.name == null
        ? truncateAddr(peer.addr)
        : '${peer.name} · ${truncateAddr(peer.addr)}';
    return Positioned(
      left: position.dx - _blipColumnWidth / 2,
      top: position.dy - _blipSize / 2,
      width: _blipColumnWidth,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: Key('radar.blip.${peer.addr}'),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _blipSize,
                height: _blipSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CmoColors.orange,
                ),
                child: Text(
                  '📡',
                  style: cmoMoneyStyle(color: Colors.white, size: 18),
                ),
              ),
              Text(
                label,
                style: cmoMoneyStyle(size: 11),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.center,
    required this.maxRadius,
    required this.pulseValue,
  });

  final Offset center;
  final double maxRadius;
  final double pulseValue; // 0..1, 0 = idle/no pulse drawn

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = CmoColors.green.withValues(alpha: 0.35);
    for (final frac in [_innerRingFrac, _midRingFrac, _outerRingFrac]) {
      canvas.drawCircle(center, frac * maxRadius, ringPaint);
    }

    canvas.drawCircle(center, 8, Paint()..color = CmoColors.navy);

    if (pulseValue > 0 && pulseValue < 1) {
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = CmoColors.orange.withValues(alpha: 1 - pulseValue);
      canvas.drawCircle(center, pulseValue * maxRadius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.center != center ||
      oldDelegate.maxRadius != maxRadius;
}
