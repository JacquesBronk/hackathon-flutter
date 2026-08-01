import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('native sqlite3 loads headless on this worker', () {
    final db = sqlite3.openInMemory();
    expect(db.select('SELECT 1 AS x').first['x'], 1);
    db.dispose();
  });
}
