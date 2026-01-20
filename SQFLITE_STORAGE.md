# 🗄️ Sqflite Storage Adapter Example

This example demonstrates how to implement a custom `KeepStorage` adapter using the `sqflite` package. This is useful for storing larger datasets or using structured database files.

## Implementation

```dart
import 'package:sqflite/sqflite.dart';
import 'package:keep/keep.dart';
import 'dart:typed_data';

class SqfliteKeepStorage extends KeepStorage {
  late Database _db;
  final String tableName = 'keep_storage';

  @override
  Future<void> init(Keep keep) async {
    final path = '${keep.root.path}/database.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            storeName TEXT PRIMARY KEY,
            payload BLOB
          )
        ''');
      },
    );
  }

  @override
  Future<void> write(KeepKey key, Object? value) async {
    if (value == null) return remove(key);

    final bytes = KeepCodec.current.encode(
      storeName: key.storeName,
      keyName: key.name,
      value: value,
      flags: (key.removable ? KeepCodec.flagRemovable : 0) | 
             (key is KeepKeySecure ? KeepCodec.flagSecure : 0),
    );

    if (bytes != null) {
      await _db.insert(
        tableName,
        {'storeName': key.storeName, 'payload': bytes},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<V?> read<V>(KeepKey key) async {
    final maps = await _db.query(
      tableName,
      where: 'storeName = ?',
      whereArgs: [key.storeName],
    );

    if (maps.isEmpty) return null;
    
    final bytes = maps.first['payload'] as Uint8List;
    final entry = KeepCodec.of(bytes).decode();
    return entry?.value as V?;
  }

  @override
  Future<void> remove(KeepKey key) async {
    await _db.delete(tableName, where: 'storeName = ?', whereArgs: [key.storeName]);
  }

  @override
  Future<bool> exists(KeepKey key) async {
    final maps = await _db.query(
      tableName,
      columns: ['storeName'],
      where: 'storeName = ?',
      whereArgs: [key.storeName],
    );
    return maps.isNotEmpty;
  }

  @override
  Future<List<String>> getKeys() async {
    final maps = await _db.query(tableName, columns: ['storeName']);
    return maps.map((e) => e['storeName'] as String).toList();
  }

  @override
  Future<void> clear() async {
    await _db.delete(tableName);
  }

  @override
  Future<void> removeKey(String storeName) async {
    await _db.delete(tableName, where: 'storeName = ?', whereArgs: [storeName]);
  }

  @override
  Future<void> clearRemovable() async {
    final keys = await getKeys();
    for (final k in keys) {
      final h = await header(k);

      if (h != null && (h.flags & KeepCodec.flagRemovable) != 0) {
        await removeKey(k);
      }
    }
  }

  @override
  Future<KeepHeader?> header(String storeName) async {
    final maps = await _db.query(
      tableName,
      columns: ['payload'],
      where: 'storeName = ?',
      whereArgs: [storeName],
    );

    if (maps.isEmpty) return null;
    
    final bytes = maps.first['payload'] as Uint8List;
    return KeepCodec.of(bytes).header();
  }

  @override
  V? readSync<V>(KeepKey key) => null;
  
  @override
  bool existsSync(KeepKey key) => false;
}
```

## Usage

```dart
final dbKeep = Keep(
  'app_db',
  externalStorage: SqfliteKeepStorage(),
);
```
