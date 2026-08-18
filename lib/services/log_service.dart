import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LogEntry {
  final int? id;
  final String timestamp;
  final String uid;
  final String operation;
  final String target;
  final String status;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.uid,
    required this.operation,
    required this.target,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'uid': uid,
      'operation': operation,
      'target': target,
      'status': status,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      timestamp: map['timestamp'],
      uid: map['uid'],
      operation: map['operation'],
      target: map['target'],
      status: map['status'],
    );
  }
}

class LogService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nfc_audit_logs.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  static Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      uid TEXT NOT NULL,
      operation TEXT NOT NULL,
      target TEXT NOT NULL,
      status TEXT NOT NULL
    )
    ''');
  }

  static Future<void> logOperation(String uid, String operation, String target, String status) async {
    final db = await database;
    final entry = LogEntry(
      timestamp: DateTime.now().toIso8601String(),
      uid: uid,
      operation: operation,
      target: target,
      status: status,
    );
    await db.insert('logs', entry.toMap());
  }

  static Future<List<LogEntry>> getLogs() async {
    final db = await database;
    final result = await db.query('logs', orderBy: 'id DESC');
    return result.map((json) => LogEntry.fromMap(json)).toList();
  }
  
  static Future<void> clearLogs() async {
      final db = await database;
      await db.delete('logs');
  }
}
