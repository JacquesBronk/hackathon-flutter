class Profile {
  const Profile(
      {required this.name, required this.avatar, required this.onboarded});
  final String name;
  final String avatar; // one emoji from the preset list
  final bool onboarded;
}

abstract interface class ProfileStore {
  Future<Profile?> load();
  Future<void> save(Profile profile);
}
