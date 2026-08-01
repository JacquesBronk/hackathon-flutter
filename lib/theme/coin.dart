import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tokens.dart';

/// The pinnie coin — the design system's single reusable money asset.
/// Flip is FINITE (single run): looping controllers hang pumpAndSettle.
class PinnieCoin extends StatefulWidget {
  const PinnieCoin({super.key, this.size = 96, this.flipOnBuild = false});
  final double size;
  final bool flipOnBuild;

  @override
  State<PinnieCoin> createState() => PinnieCoinState();
}

class PinnieCoinState extends State<PinnieCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.flipOnBuild) _c.forward();
  }

  void flip() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(_c.value * math.pi * 2),
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _CoinPainter(),
      ),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(center, r, Paint()..color = CmoColors.brass);
    canvas.drawCircle(
      center,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = CmoColors.navy.withValues(alpha: 0.25),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'ᵽ',
        style: TextStyle(
          fontSize: r,
          color: CmoColors.navy,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
