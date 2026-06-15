import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';

class AttendanceRepository {
  final _dbService = DatabaseService.instance;

  Future<List<Map<String, dynamic>>> getAvailableSections() async {
    final db = await _dbService.database;
    return await db.query('sections', columns: ['id', 'name', 'grade_level']);
  }

  Future<List<Map<String, dynamic>>> getHistoricalSectionAttendance(
    String sectionId, {
    String searchQuery = '',
    String genderFilter = 'All',
  }) async {
    final db = await _dbService.database;

    String query = '''
      SELECT a.*, s.full_name, s.gender 
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      WHERE a.section_id = ?
    ''';

    List<dynamic> args = [sectionId];

    if (searchQuery.trim().isNotEmpty) {
      query += ' AND s.full_name LIKE ?';
      args.add('%${searchQuery.trim()}%');
    }

    if (genderFilter != 'All') {
      query += ' AND s.gender = ?';
      args.add(genderFilter);
    }

    return await db.rawQuery(query, args);
  }

  // 1. READ: Fixed to explicitly select s.gender
  Future<List<Map<String, dynamic>>> getSectionAttendanceRoster(
    String sectionId,
    String date,
  ) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''SELECT s.id AS student_id, s.full_name, s.gender, a.status 
         FROM students s 
         INNER JOIN enrollments e ON s.id = e.student_id 
         LEFT JOIN attendance a ON s.id = a.student_id AND a.date = ? AND a.section_id = ?
         WHERE e.section_id = ? ORDER BY s.full_name ASC''',
      [date, sectionId, sectionId],
    );
  }

  Future<void> saveSectionAttendance({
    required String sectionId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final db = await _dbService.database;
    final batch = db.batch();

    for (var record in attendanceRecords) {
      batch.execute(
        '''
        INSERT OR REPLACE INTO attendance (id, student_id, section_id, date, status) 
        VALUES (?, ?, ?, ?, ?)
      ''',
        [
          record['id'],
          record['student_id'],
          sectionId,
          record['date'],
          record['status'],
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> deleteSectionAttendance(String sectionId, String date) async {
    final db = await _dbService.database;
    await db.delete(
      'attendance',
      where: 'date = ? AND section_id = ?',
      whereArgs: [date, sectionId],
    );
  }

  Future<Map<String, int>> getDailyAttendanceStats(String date) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT status, COUNT(*) as count FROM attendance 
      WHERE date = ? 
      GROUP BY status
    ''',
      [date],
    );

    Map<String, int> stats = {'PRESENT': 0, 'ABSENT': 0};
    for (var row in results) {
      final statusKey = row['status'] as String;
      if (stats.containsKey(statusKey)) {
        stats[statusKey] = row['count'] as int;
      }
    }
    return stats;
  }

  Future<void> saveClassAttendance({
    required String sectionId,
    required String date,
    required List<Map<String, dynamic>> studentStatuses,
  }) async {
    final db = await _dbService.database;
    final batch = db.batch();

    for (var record in studentStatuses) {
      batch.execute(
        '''
        INSERT OR REPLACE INTO attendance (id, student_id, section_id, date, status) 
        VALUES (?, ?, ?, ?, ?)
      ''',
        [
          'ATT_${record['student_id']}_SEC_${sectionId}_$date',
          record['student_id'],
          sectionId,
          date,
          record['status'],
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getClassAttendance(
    String sectionId,
    String date,
  ) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT student_id, status 
      FROM attendance 
      WHERE section_id = ? AND date = ?
    ''',
      [sectionId, date],
    );
  }

  Future<List<Map<String, dynamic>>> getAttendanceReportData({
    required String sectionId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await _dbService.database;

    return await db.rawQuery(
      '''
      SELECT 
        a.date, 
        a.status, 
        s.full_name,
        s.id as student_id
      FROM attendance a
      INNER JOIN students s ON a.date BETWEEN ? AND ? AND a.section_id = ?
      WHERE s.id = a.student_id
      ORDER BY s.full_name ASC, a.date ASC
    ''',
      [startDate, endDate, sectionId],
    );
  }

  /// Fetches an all-in-one matrix of historical enrollment, section distributions,
  /// gender splits, and live attendance metrics based on deep cross-filtering.
  Future<Map<String, dynamic>> getAdvancedAnalytics({
    String? schoolYear,
    String? gender,
    String? targetDate, // Format: YYYY-MM-DD
    String? targetMonth, // Format: MM (01-12)
    String? targetYear, // Format: YYYY
  }) async {
    // Make sure to import your DatabaseService at the top of this file!
    final db = await DatabaseService.instance.database;

    // Build independent query fragments for flexible tracking
    List<String> studentFilters = [];
    List<dynamic> studentArgs = [];

    List<String> attendanceFilters = [];
    List<dynamic> attendanceArgs = [];

    // Apply Gender Filter
    if (gender != null && gender != 'All') {
      studentFilters.add('s.gender = ?');
      studentArgs.add(gender);
      attendanceFilters.add('s.gender = ?');
      attendanceArgs.add(gender);
    }

    // Apply School Year Filter (Matching against the school_years table name)
    if (schoolYear != null && schoolYear != 'All') {
      studentFilters.add('sy.name = ?');
      studentArgs.add(schoolYear);
      attendanceFilters.add('sy.name = ?');
      attendanceArgs.add(schoolYear);
    }

    // Apply Deep Time-Series Filtering (Day, Month, Year) for Attendance
    if (targetDate != null && targetDate.isNotEmpty) {
      attendanceFilters.add('a.date LIKE ?');
      attendanceArgs.add('$targetDate%');
    }
    if (targetMonth != null && targetMonth != 'All') {
      attendanceFilters.add("strftime('%m', a.date) = ?");
      attendanceArgs.add(targetMonth);
    }
    if (targetYear != null && targetYear != 'All') {
      attendanceFilters.add("strftime('%Y', a.date) = ?");
      attendanceArgs.add(targetYear);
    }

    String studentWhere = studentFilters.isNotEmpty
        ? 'WHERE ${studentFilters.join(' AND ')}'
        : '';
    String attendanceWhere = attendanceFilters.isNotEmpty
        ? 'WHERE ${attendanceFilters.join(' AND ')}'
        : '';

    // 1. De-duplicated Enrollment & Gender Balance
    // Note: CAST(s.id AS TEXT) ensures the integer student ID matches the text student_id in enrollments
    final studentSummary = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT s.id) as totalEnrolled,
        COUNT(DISTINCT CASE WHEN s.gender = 'Male' THEN s.id END) as totalMales,
        COUNT(DISTINCT CASE WHEN s.gender = 'Female' THEN s.id END) as totalFemales
      FROM students s
      LEFT JOIN enrollments e ON CAST(s.id AS TEXT) = e.student_id
      LEFT JOIN sections sec ON e.section_id = sec.id
      LEFT JOIN school_years sy ON sec.school_year_id = sy.id
      $studentWhere
    ''', studentArgs);

    // 2. Section Allocations (Count unique students per section)
    final classSummary = await db.rawQuery('''
      SELECT 
        sec.name as className,
        COUNT(DISTINCT s.id) as classCount
      FROM sections sec
      LEFT JOIN enrollments e ON sec.id = e.section_id
      LEFT JOIN students s ON e.student_id = CAST(s.id AS TEXT)
      LEFT JOIN school_years sy ON sec.school_year_id = sy.id
      $studentWhere
      GROUP BY sec.id, sec.name
    ''', studentArgs);

    // 3. Attendance Performance Metric (Present vs Absent)
    final attendanceSummary = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN UPPER(TRIM(a.status)) = 'PRESENT' THEN 1 END) as totalPresent,
        COUNT(CASE WHEN UPPER(TRIM(a.status)) = 'ABSENT' THEN 1 END) as totalAbsent
      FROM attendance a
      LEFT JOIN sections sec ON a.section_id = sec.id
      LEFT JOIN school_years sy ON sec.school_year_id = sy.id
      LEFT JOIN students s ON CAST(s.id AS TEXT) = a.student_id
      $attendanceWhere
    ''', attendanceArgs);

    final allAttendance = await db.rawQuery('SELECT * FROM attendance');
    debugPrint('TOTAL ROWS IN ATTENDANCE: ${allAttendance.length}');
    for (var row in allAttendance) {
      debugPrint('Row: $row');
    }

    return {
      'totalEnrolled': studentSummary.first['totalEnrolled'] as int? ?? 0,
      'males': studentSummary.first['totalMales'] as int? ?? 0,
      'females': studentSummary.first['totalFemales'] as int? ?? 0,
      'classes': classSummary,
      'presentToday': attendanceSummary.first['totalPresent'] as int? ?? 0,
      'absentToday': attendanceSummary.first['totalAbsent'] as int? ?? 0,
    };
  }
}
