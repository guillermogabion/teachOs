import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';

class AttendanceRepository {
  final _dbService = DatabaseService.instance;

  Future<void> submitBulkAttendance(
    List<Map<String, dynamic>> attendanceRecords,
  ) async {
    final db = await _dbService.database;
    final batch = db.batch();
    for (var record in attendanceRecords) {
      batch.insert(
        'attendance',
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> getDailyAttendanceStats(String isoDateString) async {
    final db = await _dbService.database;
    final normalizedDate = isoDateString.split('T')[0];

    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT status, COUNT(*) as count 
      FROM attendance 
      WHERE date LIKE ? 
      GROUP BY status
      ''',
      ['$normalizedDate%'],
    );

    // Initialize map with all expected keys to prevent null errors
    final Map<String, int> stats = {
      'PRESENT': 0,
      'ABSENT': 0,
      'LATE': 0,
      'EXCUSED': 0,
    };

    for (var row in results) {
      final status = row['status'] as String;
      final count = row['count'] as int;
      if (stats.containsKey(status)) {
        stats[status] = count;
      }
    }
    return stats;
  }
}
