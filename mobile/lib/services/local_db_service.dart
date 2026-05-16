import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tariff_item.dart';

/// قاعدة البيانات المحلية على الهاتف — لا تحتاج إنترنت
class LocalDbService {
  static final LocalDbService _instance = LocalDbService._();
  factory LocalDbService() => _instance;
  LocalDbService._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'tariff_v1.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tariff_items (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            hs_code     TEXT NOT NULL DEFAULT '',
            item_name   TEXT NOT NULL DEFAULT '',
            duty_rate   TEXT DEFAULT '',
            total_fees  TEXT DEFAULT '',
            description TEXT DEFAULT '',
            source_file TEXT DEFAULT ''
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_hs   ON tariff_items(hs_code)');
        await db.execute(
            'CREATE INDEX idx_name ON tariff_items(item_name)');

        await db.execute('''
          CREATE TABLE imported_files (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            filename    TEXT NOT NULL,
            item_count  INTEGER DEFAULT 0,
            imported_at TEXT DEFAULT (datetime('now','localtime'))
          )
        ''');
      },
    );
  }

  // ─── بحث ───────────────────────────────────────────────────────────
  Future<List<TariffItem>> search(String query, {int limit = 40}) async {
    final db = await _database;
    final like = '%$query%';
    final rows = await db.rawQuery('''
      SELECT * FROM tariff_items
      WHERE hs_code LIKE ? OR item_name LIKE ? OR description LIKE ?
      ORDER BY
        CASE WHEN hs_code = ? OR item_name = ? THEN 0 ELSE 1 END,
        item_name COLLATE NOCASE
      LIMIT ?
    ''', [like, like, like, query, query, limit]);
    return rows.map(TariffItem.fromJson).toList();
  }

  // ─── تفاصيل صنف ────────────────────────────────────────────────────
  Future<TariffItem?> getItem(int id) async {
    final db = await _database;
    final rows = await db.query(
      'tariff_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TariffItem.fromJson(rows.first);
  }

  // ─── إدخال البيانات المستخرجة من PDF ────────────────────────────────
  Future<int> insertItems(
    List<Map<String, String>> items,
    String sourceFile,
  ) async {
    final db = await _database;
    final batch = db.batch();

    // حذف بيانات الملف القديم إن وُجد
    batch.delete(
      'tariff_items',
      where: 'source_file = ?',
      whereArgs: [sourceFile],
    );
    batch.delete(
      'imported_files',
      where: 'filename = ?',
      whereArgs: [sourceFile],
    );

    for (final item in items) {
      batch.insert('tariff_items', {...item, 'source_file': sourceFile});
    }

    batch.insert('imported_files', {
      'filename': sourceFile,
      'item_count': items.length,
    });

    await batch.commit(noResult: true);
    return items.length;
  }

  // ─── قائمة الملفات المستوردة ─────────────────────────────────────────
  Future<List<ImportedFile>> listFiles() async {
    final db = await _database;
    final rows = await db.query(
      'imported_files',
      orderBy: 'imported_at DESC',
    );
    return rows.map(ImportedFile.fromMap).toList();
  }

  // ─── حذف ملف وبياناته ────────────────────────────────────────────────
  Future<void> deleteFile(int id, String filename) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('tariff_items',
        where: 'source_file = ?', whereArgs: [filename]);
    batch.delete('imported_files', where: 'id = ?', whereArgs: [id]);
    await batch.commit();
  }

  // ─── إحصائيات ────────────────────────────────────────────────────────
  Future<Map<String, int>> getStats() async {
    final db = await _database;
    final items = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tariff_items'),
        ) ??
        0;
    final files = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM imported_files'),
        ) ??
        0;
    return {'total_items': items, 'total_files': files};
  }
}

// ─── نموذج الملف المستورد ─────────────────────────────────────────────
class ImportedFile {
  final int id;
  final String filename;
  final int itemCount;
  final String importedAt;

  const ImportedFile({
    required this.id,
    required this.filename,
    required this.itemCount,
    required this.importedAt,
  });

  factory ImportedFile.fromMap(Map<String, dynamic> m) => ImportedFile(
        id: m['id'] as int,
        filename: m['filename'] as String,
        itemCount: m['item_count'] as int? ?? 0,
        importedAt: m['imported_at'] as String? ?? '',
      );
}
