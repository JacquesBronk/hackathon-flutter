// Store-and-forward persistence (spec §2.2 rule 5).
abstract interface class OutboxStore {
  Future<void> put(String msgId, String frameJson, DateTime expiresAt);
  Future<void> remove(String msgId);
  Future<List<(String msgId, String frameJson)>> pending();
}
