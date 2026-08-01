// Dedupe-cache persistence for GossipEngine's seen set. Drift adapter caps
// at 1024 (LRU); this fake/interface places no bound.
abstract interface class SeenStore {
  Future<Set<String>> load();
  Future<void> add(String msgId);
}
