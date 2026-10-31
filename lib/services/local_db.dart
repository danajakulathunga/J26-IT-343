import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bananaguard_ai/models/notification_item.dart';
import 'package:bananaguard_ai/models/scan_result.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  // Web in-memory fallbacks
  final List<ScanResultModel> _webScans = [];
  final List<NotificationItem> _webNotifications = [];

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bananaguard_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_scans (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            condition_id TEXT NOT NULL,
            condition_type TEXT NOT NULL,
            severity_level TEXT,
            severity_index REAL NOT NULL,
            raw_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            payload TEXT
          )
        ''');
      },
    );
  }

  // --- Scan Cache ---
  Future<void> saveScan(ScanResultModel scan) async {
    _webScans.removeWhere((s) => s.scanId == scan.scanId);
    _webScans.insert(0, scan);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawList = _webScans.map((s) => jsonEncode(s.toJson())).toList();
        await prefs.setStringList('web_cached_scans', rawList);
      } catch (_) {}
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.insert(
      'cached_scans',
      {
        'id': scan.scanId,
        'created_at': scan.createdAt,
        'condition_id': scan.condition.id,
        'condition_type': scan.condition.type,
        'severity_level': scan.severity?.level,
        'severity_index': scan.severityIndex,
        'raw_json': jsonEncode(scan.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScanResultModel>> getCachedScans() async {
    if (kIsWeb) {
      if (_webScans.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final rawList = prefs.getStringList('web_cached_scans') ?? [];
          for (final raw in rawList) {
            _webScans.add(ScanResultModel.fromJson(jsonDecode(raw) as Map<String, dynamic>));
          }
        } catch (_) {}
      }
      return List.unmodifiable(_webScans);
    }

    final db = await database;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'cached_scans',
      orderBy: 'created_at DESC',
    );
    return maps.map((row) {
      final json = jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
      return ScanResultModel.fromJson(json);
    }).toList();
  }

  Future<void> deleteCachedScan(String id) async {
    _webScans.removeWhere((s) => s.scanId == id);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawList = _webScans.map((s) => jsonEncode(s.toJson())).toList();
        await prefs.setStringList('web_cached_scans', rawList);
      } catch (_) {}
      return;
    }

    final db = await database;
    if (db != null) {
      await db.delete('cached_scans', where: 'id = ?', whereArgs: [id]);
    }
  }

  // --- Notifications Inbox ---
  Future<void> insertNotification(NotificationItem item) async {
    if (kIsWeb) {
      _webNotifications.removeWhere((n) => n.id == item.id);
      _webNotifications.insert(0, item);
      return;
    }

    final db = await database;
    if (db != null) {
      await db.insert('notifications', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<NotificationItem>> getNotifications() async {
    if (kIsWeb) {
      return List.unmodifiable(_webNotifications);
    }

    final db = await database;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => NotificationItem.fromMap(e)).toList();
  }

  Future<void> markAsRead(String id) async {
    if (kIsWeb) {
      final idx = _webNotifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _webNotifications[idx] = _webNotifications[idx].copyWith(isRead: true);
      }
      return;
    }

    final db = await database;
    if (db != null) {
      await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> markAllAsRead() async {
    if (kIsWeb) {
      for (var i = 0; i < _webNotifications.length; i++) {
        _webNotifications[i] = _webNotifications[i].copyWith(isRead: true);
      }
      return;
    }

    final db = await database;
    if (db != null) {
      await db.update('notifications', {'is_read': 1});
    }
  }

  Future<void> deleteNotification(String id) async {
    if (kIsWeb) {
      _webNotifications.removeWhere((n) => n.id == id);
      return;
    }

    final db = await database;
    if (db != null) {
      await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
    }
  }
}

final localDbService = LocalDbService();
