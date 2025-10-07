import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for handling offline report storage and synchronization
class OfflineStorageService {
  static Database? _database;
  static const String _tableName = 'pending_reports';

  /// Initialize the database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database with proper schema
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'safe_voice_offline.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            caseId TEXT NOT NULL,
            type TEXT NOT NULL,
            reportText TEXT,
            audioFilePath TEXT,
            additionalText TEXT,
            location TEXT,
            incidentDate TEXT,
            attachmentPaths TEXT,
            createdAt TEXT NOT NULL,
            retryCount INTEGER DEFAULT 0,
            lastErrorMessage TEXT
          )
        ''');
      },
    );
  }

  /// Store a text report offline
  static Future<String> storeTextReportOffline({
    required String caseId,
    required String reportText,
    String? location,
    DateTime? incidentDate,
    List<String>? attachmentPaths,
  }) async {
    final db = await database;
    
    Map<String, dynamic> report = {
      'caseId': caseId,
      'type': 'text',
      'reportText': reportText,
      'location': location,
      'incidentDate': incidentDate?.toIso8601String(),
      'attachmentPaths': attachmentPaths != null ? jsonEncode(attachmentPaths) : null,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await db.insert(_tableName, report);
    return caseId;
  }

  /// Store a voice report offline
  static Future<String> storeVoiceReportOffline({
    required String caseId,
    required String audioFilePath,
    String? additionalText,
    String? location,
    DateTime? incidentDate,
  }) async {
    final db = await database;
    
    Map<String, dynamic> report = {
      'caseId': caseId,
      'type': 'voice',
      'audioFilePath': audioFilePath,
      'additionalText': additionalText,
      'location': location,
      'incidentDate': incidentDate?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await db.insert(_tableName, report);
    return caseId;
  }

  /// Get all pending reports
  static Future<List<Map<String, dynamic>>> getPendingReports() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'createdAt ASC');
  }

  /// Remove a successfully uploaded report
  static Future<void> removePendingReport(String caseId) async {
    final db = await database;
    await db.delete(_tableName, where: 'caseId = ?', whereArgs: [caseId]);
  }

  /// Update retry count and error message for a failed report
  static Future<void> updateRetryCount(String caseId, String errorMessage) async {
    final db = await database;
    
    // Get current retry count
    List<Map<String, dynamic>> reports = await db.query(
      _tableName, 
      where: 'caseId = ?', 
      whereArgs: [caseId]
    );
    
    if (reports.isNotEmpty) {
      int currentRetryCount = reports[0]['retryCount'] ?? 0;
      await db.update(
        _tableName,
        {
          'retryCount': currentRetryCount + 1,
          'lastErrorMessage': errorMessage,
        },
        where: 'caseId = ?',
        whereArgs: [caseId],
      );
    }
  }

  /// Check if device is online  
  static Future<bool> isOnline() async {
    try {
      ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
      
      return connectivityResult == ConnectivityResult.mobile || 
             connectivityResult == ConnectivityResult.wifi ||
             connectivityResult == ConnectivityResult.ethernet;
    } catch (e) {
      // If connectivity check fails, assume offline
      return false;
    }
  }

  /// Get count of pending reports
  static Future<int> getPendingReportsCount() async {
    final db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear old failed reports (older than 7 days with retry count > 5)
  static Future<void> clearOldFailedReports() async {
    final db = await database;
    String sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    await db.delete(
      _tableName,
      where: 'createdAt < ? AND retryCount > 5',
      whereArgs: [sevenDaysAgo],
    );
  }

  /// Get storage statistics
  static Future<Map<String, int>> getStorageStats() async {
    final db = await database;
    
    // Count by type
    var textCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE type = "text"');
    var voiceCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE type = "voice"');
    
    // Count by retry status
    var failedCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE retryCount > 3');
    
    return {
      'total': await getPendingReportsCount(),
      'text': Sqflite.firstIntValue(textCount) ?? 0,
      'voice': Sqflite.firstIntValue(voiceCount) ?? 0,
      'failed': Sqflite.firstIntValue(failedCount) ?? 0,
    };
  }
}
