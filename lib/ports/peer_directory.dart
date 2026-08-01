abstract interface class PeerDirectory {
  Future<void> record(String addr, String name);
  Future<String?> nameFor(String addr);

  /// Every peer ever recorded (from scanned rr QRs and mesh presence).
  /// Powers the mesh-send picker's "any user ever seen" union (spec §2.4) —
  /// offline directory peers are pickable; delivery rides the outbox.
  Future<List<({String addr, String name})>> entries();
}
