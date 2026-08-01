import 'package:cash_me_outside/adapters/prefs_profile_store.dart';
import 'package:cash_me_outside/ports/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trips profile', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsProfileStore();
    expect(await store.load(), isNull);
    await store.save(const Profile(name: 'J', avatar: '🦫', onboarded: true));
    final loaded = await store.load();
    expect(loaded!.name, 'J');
    expect(loaded.avatar, '🦫');
    expect(loaded.onboarded, isTrue);
  });
}
