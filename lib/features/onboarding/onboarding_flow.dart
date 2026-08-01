import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';
import '../wallet/wallet_screen.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _page = PageController();
  final _name = TextEditingController();
  String _avatar = presetAvatars.first;
  bool _minting = false;

  void _next() => _page.nextPage(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  Future<void> _createWallet() async {
    setState(() => _minting = true);
    await ref
        .read(profileControllerProvider.notifier)
        .createWallet(name: _name.text.trim(), avatar: _avatar);
    if (mounted) setState(() => _minting = false);
  }

  Future<void> _finish() async {
    // Navigate FIRST. Flipping onboarded before leaving rebuilds RootGate
    // into the unlock screen while this route exits → a second OS biometric
    // sheet on real devices. (Grab the notifier before this State disposes.)
    final notifier = ref.read(profileControllerProvider.notifier);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WalletScreen()));
    await notifier.markOnboarded();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageView(
      controller: _page,
      physics: const NeverScrollableScrollPhysics(),
      children: [_identityStep(), _mintStep(), _biometricStep()],
    ),
  );

  Widget _identityStep() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Who's getting paid?",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          TextField(
            key: const Key('onboard.name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in presetAvatars)
                ChoiceChip(
                  key: Key('onboard.avatar.$a'),
                  // Spec §2.6: preset emoji rendered on a brass coin disc.
                  label: CircleAvatar(
                    backgroundColor: CmoColors.brass,
                    radius: 18,
                    child: Text(a, style: const TextStyle(fontSize: 20)),
                  ),
                  selected: _avatar == a,
                  onSelected: (_) => setState(() => _avatar = a),
                ),
            ],
          ),
          const Spacer(),
          FilledButton(
            key: const Key('onboard.next'),
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              await _createWallet();
              _next();
            },
            child: const Text('Mint my wallet'),
          ),
        ],
      ),
    ),
  );

  Widget _mintStep() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const PinnieCoin(flipOnBuild: true, size: 140),
        const SizedBox(height: 16),
        Text('ᵽ500 minted', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('onboard.mint.next'),
          onPressed: _minting ? null : _next,
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  Widget _biometricStep() => Center(
    child: FutureBuilder<bool>(
      future: ref.read(biometricGateProvider).isAvailable,
      builder: (context, snap) {
        final available = snap.data ?? false;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Lock it down',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              available
                  ? 'Your fingerprint signs every send.'
                  : 'No biometrics enrolled on this device.\n'
                        'Enroll in Settings for the full experience.',
            ),
            const SizedBox(height: 24),
            if (available)
              FilledButton(
                key: const Key('onboard.biometric'),
                onPressed: () async {
                  final ok = await ref
                      .read(biometricGateProvider)
                      .authenticate('Secure your wallet');
                  if (ok) await _finish();
                },
                child: const Text('Enable biometric lock'),
              )
            else
              TextButton(
                key: const Key('onboard.skip'),
                onPressed: _finish,
                child: const Text('Skip for now (unsafe, but go off)'),
              ),
          ],
        );
      },
    ),
  );
}
