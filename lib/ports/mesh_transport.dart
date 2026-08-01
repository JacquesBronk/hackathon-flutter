class MeshPeer {
  const MeshPeer({
    required this.addr,
    required this.name,
    required this.rssi,
    required this.lastSeen,
  });

  final String addr;
  final String? name; // unauthenticated — display rules apply
  final int rssi;
  final DateTime lastSeen;
}

abstract interface class MeshTransport {
  Future<void> start(); // begin advertise + scan + connect
  Future<void> stop();
  Stream<MeshPeer>
  get peerEvents; // connect/update events (rssi refreshes re-emit)
  Stream<String> get inboundFrames; // whole envelope JSON strings
  Future<void> broadcastFrame(String frameJson); // to all connected peers
}
