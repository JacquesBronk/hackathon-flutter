import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/mesh/envelope.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';

/// Cosmetic "full cup" reference point for the fill animation — pour
/// sessions are open-ended, so this is a visual scale, not a protocol value.
const _cupCapacity = 25;

/// Pour catch mode (spec §3), following the existing receive screen's
/// pattern: the cup fills from [PourController.catchState], folded from the
/// highest-`seq` `pour` envelope per session — out-of-order relay delivery
/// safe. Purely cosmetic; the actual balance moves separately when the
/// sender's [PourController.finishPour] signed tx is gossiped and ingested
/// through the ordinary mesh `tx` path.
class CatchScreen extends ConsumerWidget {
  const CatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catchState = ref
        .watch(pourControllerProvider)
        .valueOrNull
        ?.catchState;
    return Scaffold(
      appBar: AppBar(title: const Text('Catch')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: catchState == null
              ? const Text('Waiting for a pour…', textAlign: TextAlign.center)
              : _Cup(state: catchState),
        ),
      ),
    );
  }
}

class _Cup extends StatelessWidget {
  const _Cup({required this.state});
  final PourCatchState state;

  @override
  Widget build(BuildContext context) {
    final fraction = (state.pouredTotal / _cupCapacity).clamp(0.0, 1.0);
    final done = state.state == pourStateFinal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (done)
          const PinnieCoin(flipOnBuild: true)
        else
          const SizedBox(height: 96),
        const SizedBox(height: 16),
        Container(
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: CmoColors.navy, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              key: const Key('pour.catch.cup'),
              heightFactor: fraction,
              widthFactor: 1,
              child: const ColoredBox(color: CmoColors.orange),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          done ? '+ᵽ${state.pouredTotal}' : 'ᵽ${state.pouredTotal}',
          style: cmoAmountStyle(
            color: done ? CmoColors.green : CmoColors.orange,
          ),
        ),
        if (done) const Text('Caught it!'),
      ],
    );
  }
}
