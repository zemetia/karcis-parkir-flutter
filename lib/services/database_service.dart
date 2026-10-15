import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/parking_ticket.dart';

class DatabaseService {
  static const String _dbName = 'karcis_parkir.db';
  static const String _tableName = 'tickets';
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();

  String? customDbPath;

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      if (databaseFactory != databaseFactoryFfi) {
        databaseFactory = databaseFactoryFfi;
      }
    }

    String dbPath;
    if (customDbPath != null) {
      dbPath = customDbPath!;
    } else {
      try {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
          final appSupportDir = await getApplicationSupportDirectory();
          dbPath = p.join(appSupportDir.path, _dbName);
        } else {
          final databasesPath = await getDatabasesPath();
          dbPath = p.join(databasesPath, _dbName);
        }
      } catch (_) {
        // Fallback for tests / headless environments
        dbPath = inMemoryDatabasePath;
      }
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            rawCode TEXT NOT NULL,
            format TEXT NOT NULL,
            plateNumber TEXT,
            vehicleType TEXT NOT NULL,
            locationName TEXT,
            entryTime TEXT NOT NULL,
            notes TEXT,
            createdAt TEXT NOT NULL,
            firstReminderHours REAL NOT NULL,
            secondReminderHours REAL NOT NULL,
            reminderHours TEXT,
            isCompleted INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE $_tableName ADD COLUMN reminderHours TEXT;');
          } catch (_) {}
        }
      },
    );
  }

  Future<int> insertTicket(ParkingTicket ticket) async {
    final db = await database;
    return await db.insert(
      _tableName,
      ticket.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ParkingTicket>> getActiveTickets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isCompleted = ?',
      whereArgs: [0],
      orderBy: 'entryTime DESC',
    );
    return maps.map((m) => ParkingTicket.fromMap(m)).toList();
  }

  Future<List<ParkingTicket>> getAllTickets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'entryTime DESC',
    );
    return maps.map((m) => ParkingTicket.fromMap(m)).toList();
  }

  Future<ParkingTicket?> getTicketById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ParkingTicket.fromMap(maps.first);
  }

  Future<int> deleteTicket(String id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTicket(ParkingTicket ticket) async {
    final db = await database;
    return await db.update(
      _tableName,
      ticket.toMap(),
      where: 'id = ?',
      whereArgs: [ticket.id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
