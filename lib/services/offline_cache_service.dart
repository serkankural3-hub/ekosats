import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:convert';

class OfflineCacheService {
  static Database? _database;
  static const String _tableName = 'cart_records_cache';
  static const String _pendingTable = 'pending_operations';
  static const String _syncErrorTable = 'sync_errors';
  // In-memory cache for web where sqflite is unavailable
  static final Map<String, Map<String, dynamic>> _memCache = {};
  static final List<Map<String, dynamic>> _memPending = [];
  static final List<Map<String, dynamic>> _memSyncErrors = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Web'de SQLite yok: çağıranlar web'de DB'ye dokunmamalı
    if (kIsWeb) {
      throw StateError('Web environment uses in-memory offline cache; database is not available.');
    }
    // Windows/Linux/macOS desteği için sqflite_common_ffi kullan
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ekosats_cache.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Cache table
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        // Pending operations table
        await db.execute('''
          CREATE TABLE $_pendingTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            collection TEXT NOT NULL,
            documentId TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        // Sync errors table — senkronizasyon hatalarını kaydet
        await db.execute('''
          CREATE TABLE $_syncErrorTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operationId INTEGER,
            errorMessage TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: Sync errors table ekle
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_syncErrorTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operationId INTEGER,
              errorMessage TEXT NOT NULL,
              timestamp INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  // Cache kayıt
  Future<void> cacheRecord(String id, Map<String, dynamic> data) async {
    if (kIsWeb) {
      _memCache[id] = data;
      return;
    }
    final db = await database;
    await db.insert(
      _tableName,
      {
        'id': id,
        'data': jsonEncode(data),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Tüm cache'i al
  Future<List<Map<String, dynamic>>> getCachedRecords() async {
    if (kIsWeb) {
      return _memCache.values.toList();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return maps.map((map) => jsonDecode(map['data'] as String) as Map<String, dynamic>).toList();
  }

  // Belirli bir kaydı al
  Future<Map<String, dynamic>?> getCachedRecord(String id) async {
    if (kIsWeb) {
      return _memCache[id];
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
  }

  // Pending operation ekle
  Future<void> addPendingOperation({
    required String operation, // 'create', 'update', 'delete'
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) {
      _memPending.add({
        'operation': operation,
        'collection': collection,
        'documentId': documentId,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }
    final db = await database;
    await db.insert(_pendingTable, {
      'operation': operation,
      'collection': collection,
      'documentId': documentId,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Pending operations'ı al
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    if (kIsWeb) {
      return _memPending;
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _pendingTable,
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) {
      return {
        'id': map['id'],
        'operation': map['operation'],
        'collection': map['collection'],
        'documentId': map['documentId'],
        'data': jsonDecode(map['data'] as String),
        'timestamp': map['timestamp'],
      };
    }).toList();
  }

  // Pending operation'ı sil
  Future<void> deletePendingOperation(int id) async {
    if (kIsWeb) {
      _memPending.removeWhere((op) => op['id'] == id);
      return;
    }
    final db = await database;
    await db.delete(
      _pendingTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Senkronizasyon hatası kaydet
  Future<void> recordSyncError(int? operationId, String errorMessage) async {
    if (kIsWeb) {
      _memSyncErrors.add({
        'operationId': operationId,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }
    final db = await database;
    await db.insert(
      _syncErrorTable,
      {
        'operationId': operationId,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Senkronizasyon hatalarını al
  Future<List<Map<String, dynamic>>> getSyncErrors() async {
    if (kIsWeb) {
      return _memSyncErrors;
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _syncErrorTable,
      orderBy: 'timestamp DESC',
      limit: 100,
    );
    return maps;
  }

  // Pending operations sayısını al
  Future<int> getPendingOperationsCount() async {
    if (kIsWeb) {
      return _memPending.length;
    }
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_pendingTable');
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      return result.first.values.first as int? ?? 0;
    }
    return 0;
  }

  // Cache'i temizle (eski veriler silinmeyecek)
  Future<void> clearCache() async {
    if (kIsWeb) {
      _memCache.clear();
      return;
    }
    final db = await database;
    await db.delete(_tableName);
  }

  // Tüm pending operations'ı temizle
  Future<void> clearPendingOperations() async {
    if (kIsWeb) {
      _memPending.clear();
      return;
    }
    final db = await database;
    await db.delete(_pendingTable);
  }

  // Eski sync hatalarını temizle (30 günden eski)
  Future<void> clearOldSyncErrors() async {
    if (kIsWeb) {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;
      _memSyncErrors.removeWhere((e) => (e['timestamp'] as int) < thirtyDaysAgo);
      return;
    }
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;
    await db.delete(
      _syncErrorTable,
      where: 'timestamp < ?',
      whereArgs: [thirtyDaysAgo],
    );
  }

  // Cache boyutunu al
  Future<int> getCacheSize() async {
    if (kIsWeb) {
      return _memCache.length;
    }
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      return result.first.values.first as int? ?? 0;
    }
    return 0;
  }

  // Pres kayıtlarını al (press_records collection'dan)
  Future<List<Map<String, dynamic>>> getPressRecords() async {
    if (kIsWeb) {
      return _memCache.values
          .where((data) => ((data['createdBy'] ?? '') as String).toLowerCase().contains('pres'))
          .toList();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return maps
        .where((map) {
          final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
          final createdBy = (data['createdBy'] ?? '').toString().toLowerCase();
          return createdBy.contains('pres');
        })
        .map((map) => jsonDecode(map['data'] as String) as Map<String, dynamic>)
        .toList();
  }
}

