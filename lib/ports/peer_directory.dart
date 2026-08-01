abstract interface class PeerDirectory {
  Future<void> record(String addr, String name);
  Future<String?> nameFor(String addr);
}
