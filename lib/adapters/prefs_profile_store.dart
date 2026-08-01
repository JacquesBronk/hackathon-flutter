import 'package:shared_preferences/shared_preferences.dart';
import '../ports/profile_store.dart';

class PrefsProfileStore implements ProfileStore {
  @override
  Future<Profile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile.name');
    if (name == null) return null;
    return Profile(
      name: name,
      avatar: prefs.getString('profile.avatar') ?? '🦫',
      onboarded: prefs.getBool('profile.onboarded') ?? false,
    );
  }

  @override
  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile.name', profile.name);
    await prefs.setString('profile.avatar', profile.avatar);
    await prefs.setBool('profile.onboarded', profile.onboarded);
  }
}
