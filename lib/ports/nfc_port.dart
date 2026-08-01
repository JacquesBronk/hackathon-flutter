/// Payloads are existing `cmo:rr1:`/`cmo:tx1:`/`cmo:v1:` URIs — nothing new
/// to parse (spec §4).
abstract interface class NfcPort {
  Future<void> writeTag(String uri);
  Stream<String> get tagsRead;
  Future<void> startHceSession(String uri);
  Future<void> stopHceSession();
}
