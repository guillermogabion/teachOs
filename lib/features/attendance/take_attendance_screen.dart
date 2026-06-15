import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';

class AttendanceRepository {
  final _dbService = DatabaseService.instance;

  /// Saves or overwrites a list of student attendance records for a specific date and subject
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

  /// Gets quick daily statistics for the dashboard counter
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

    Map<String, int> stats = {
      'PRESENT': 0,
      'ABSENT': 0,
      'LATE': 0,
      'EXCUSED': 0,
    };
    for (var row in results) {
      stats[row['status'] as String] = row['count'] as int;
    }
    return stats;
  }
}
