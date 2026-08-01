import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

import '../providers.dart';

/// Splits [total] pinnies across [recipients]: every share >= 1, shares sum
/// exactly to [total], deterministic given [random]. Throws if there isn't
/// enough to give every recipient at least one pinnie.
List<int> splitRain(int total, List<String> recipients, {Random? random}) {
  final n = recipients.length;
  if (n == 0) throw ArgumentError('no recipients');
  if (total < n) {
    throw ArgumentError(
      'total ($total) must be >= recipient count ($n) — every share needs '
      'at least 1 pinnie',
    );
  }
  final rand = random ?? Random();
  final remainder = total - n;
  if (remainder == 0) return List<int>.filled(n, 1);
  // n-1 random cut points over [0, remainder] partition the remainder into
  // n non-negative pieces, each added to a guaranteed base share of 1.
  final cuts = List<int>.generate(n - 1, (_) => rand.nextInt(remainder + 1))
    ..sort();
  final shares = <int>[];
  var prev = 0;
  for (final cut in cuts) {
    shares.add(1 + (cut - prev));
    prev = cut;
  }
  shares.add(1 + (remainder - prev));
  return shares;
}

class RainState {
  const RainState();
}

/// Make-it-rain: one biometric approval covers the whole burst, then one
/// signed tx per recipient via [MeshController.sendMeshTx] (which already
/// handles gossiping each targeted send) — no new ledger rules.
class RainController extends AsyncNotifier<RainState> {
  @override
  Future<RainState> build() async {
    await ref.read(meshControllerProvider.future);
    return const RainState();
  }

  /// Returns the tx ids sent, in the same order as [recipients], or `null`
  /// if biometrics were denied (nothing was sent).
  Future<List<String>?> makeItRain({
    required int total,
    required List<String> recipients,
    Random? random,
  }) async {
    await future;
    final shares = splitRain(total, recipients, random: random);
    final approved = await ref
        .read(biometricGateProvider)
        .authenticate('Confirm sending ᵽ$total to ${recipients.length} phones');
    if (!approved) return null;
    final txIds = <String>[];
    for (var i = 0; i < recipients.length; i++) {
      txIds.add(
        await ref
            .read(meshControllerProvider.notifier)
            .sendMeshTx(to: recipients[i], amount: shares[i]),
      );
    }
    return txIds;
  }
}
