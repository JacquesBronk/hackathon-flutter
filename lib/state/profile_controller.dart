import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/keys.dart';
import '../providers.dart';

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() => ref.read(profileStoreProvider).load();

  Future<void> createWallet({
    required String name,
    required String avatar,
  }) async {
    final keys = await WalletKeys.generate();
    await ref.read(keyVaultProvider).storeSeed(await keys.seed());
    ref.invalidate(walletKeysProvider);
    final profile = Profile(name: name, avatar: avatar, onboarded: false);
    await ref.read(profileStoreProvider).save(profile);
    state = AsyncData(profile);
    await ref.read(ledgerControllerProvider.notifier).mintSelf();
  }

  Future<void> markOnboarded() async {
    final current = state.value!;
    final updated = Profile(
      name: current.name,
      avatar: current.avatar,
      onboarded: true,
    );
    await ref.read(profileStoreProvider).save(updated);
    state = AsyncData(updated);
  }
}
