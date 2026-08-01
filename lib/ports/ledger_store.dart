import '../domain/transaction.dart';

abstract interface class LedgerStore {
  Future<List<Transaction>> loadAll();
  Future<void> save(Transaction tx);
  Future<int> loadLamport();
  Future<void> saveLamport(int value);
}
