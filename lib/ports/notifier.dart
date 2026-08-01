abstract interface class Notifier {
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}
