import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../onboarding/onboarding_flow.dart';
import '../wallet/wallet_screen.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Spec §5: storage errors are RETRYABLE, never dead ends.
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Storage hiccup — your pinnies are safe.'),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('root.retry'),
                onPressed: () {
                  ref.invalidate(profileControllerProvider);
                  ref.invalidate(ledgerControllerProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (p) => (p == null || !p.onboarded)
          ? const OnboardingFlow()
          : const _UnlockScreen(),
    );
  }
}

class _UnlockScreen extends ConsumerStatefulWidget {
  const _UnlockScreen();
  @override
  ConsumerState<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<_UnlockScreen> {
  bool _unlocked = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    final ok = await ref
        .read(biometricGateProvider)
        .authenticate('Unlock your wallet');
    if (mounted) {
      setState(() {
        _unlocked = ok;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const WalletScreen();
    return Scaffold(
      body: Center(
        child: _failed
            ? FilledButton(
                key: const Key('unlock.retry'),
                onPressed: _tryUnlock,
                child: const Text('Unlock'),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
