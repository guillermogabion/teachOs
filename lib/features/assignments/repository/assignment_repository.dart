import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';

class AssignmentRepository {
  final _dbService = DatabaseService.instance;

  // 1. Fetch Classes (Reusing your existing sections query)
  Future<List<Map<String, dynamic>>> getActiveClasses() async {
    final db = await _dbService.database;
    return await db.query(
      'sections',
      where: 'is_archived = 0',
      orderBy: 'name ASC',
    );
  }

  // 1B. Fetch ONLY Archived Classes
  Future<List<Map<String, dynamic>>> getArchivedClasses() async {
    final db = await _dbService.database;
    return await db.query(
      'sections',
      where: 'is_archived = 1',
      orderBy: 'name ASC',
    );
  }

  // Backward-compat alias — dashboard screen still calls the old name
  Future<List<Map<String, dynamic>>> getStudentAveragesPerQuarter({
    required String sectionId,
    required String periodId,
  }) => getStudentAveragesPerPeriod(sectionId: sectionId, periodId: periodId);

  Future<void> toggleArchiveStatus(String sectionId, int status) async {
    final db = await _dbService.database;
    await db.update(
      'sections',
      {'is_archived': status},
      where: 'id = ?',
      whereArgs: [sectionId],
    );
  }

  // 2. Fetch Assignments for a specific class
  Future<List<Map<String, dynamic>>> getAssignments(String sectionId) async {
    final db = await _dbService.database;
    return await db.query(
      'assignments',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'due_date ASC',
    );
  }

  // 3. Create Assignment & Auto-Generate Trackers for Enrolled Students
  Future<void> createAssignment({
    required String sectionId,
    required String title,
    required String type,
    required String dueDate,
    required int maxScore,
    required String periodId,
  }) async {
    final db = await _dbService.database;
    final assignmentId = const Uuid().v4();

    await db.transaction((txn) async {
      await txn.insert('assignments', {
        'id': assignmentId,
        'section_id': sectionId,
        'title': title,
        'type': type,
        'due_date': dueDate,
        'max_score': maxScore,
        'period_id': periodId,
      });

      // Fetch all students enrolled in this class
      final enrolledStudents = await txn.query(
        'enrollments',
        columns: ['student_id'],
        where: 'section_id = ?',
        whereArgs: [sectionId],
      );

      // Create a 'Pending' submission status for every student instantly
      for (var row in enrolledStudents) {
        await txn.insert('submissions', {
          'id': const Uuid().v4(),
          'assignment_id': assignmentId,
          'student_id': row['student_id'],
          'status': 'Pending',
        });
      }
    });
  }

  // 4. Fetch the Submission Matrix for an Assignment
  Future<List<Map<String, dynamic>>> getSubmissionTracking(
    String assignmentId,
  ) async {
    final db = await _dbService.database;

    final assignData = await db.query(
      'assignments',
      columns: ['section_id'],
      where: 'id = ?',
      whereArgs: [assignmentId],
    );
    if (assignData.isEmpty) return [];
    final sectionId = assignData.first['section_id'];

    return await db.rawQuery(
      '''
      SELECT 
        s.id AS student_id,
        s.full_name,
        sub.id AS submission_id,
        COALESCE(sub.status, 'Pending') AS status,
        sub.score
      FROM enrollments e
      INNER JOIN students s ON e.student_id = s.id
      LEFT JOIN submissions sub ON sub.student_id = e.student_id AND sub.assignment_id = ?
      WHERE e.section_id = ?
      ORDER BY s.full_name ASC
    ''',
      [assignmentId, sectionId],
    );
  }

  // 5. Update a student's submission status
  Future<void> updateSubmissionStatus({
    required String assignmentId,
    required String studentId,
    required String status,
    double? score,
  }) async {
    final db = await _dbService.database;

    final existing = await db.query(
      'submissions',
      where: 'assignment_id = ? AND student_id = ?',
      whereArgs: [assignmentId, studentId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'submissions',
        {'status': status, 'score': score},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('submissions', {
        'id': const Uuid().v4(),
        'assignment_id': assignmentId,
        'student_id': studentId,
        'status': status,
        'score': score,
      });
    }
  }

  // Get available periods for a section (loaded from framework, not hardcoded quarters)
  Future<List<Map<String, dynamic>>> getAvailablePeriods(
    String sectionId,
  ) async {
    final db = await _dbService.database;

    final sectionData = await db.query(
      'sections',
      columns: ['framework_id'],
      where: 'id = ?',
      whereArgs: [sectionId],
    );

    if (sectionData.isEmpty) return [];

    final frameworkId = sectionData.first['framework_id'] as String;

    return await db.query(
      'academic_periods',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
      orderBy: 'order_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getStudentAveragesPerPeriod({
    required String sectionId,
    required String periodId,
  }) async {
    final db = await _dbService.database;

    return await db.rawQuery(
      '''
      WITH PeriodStats AS (
          SELECT 
              sub.student_id,
              SUM(CASE WHEN sub.status IN ('Submitted', 'Late') THEN sub.score ELSE 0 END) as period_earned,
              SUM(a.max_score) as period_possible
          FROM assignments a
          JOIN submissions sub ON a.id = sub.assignment_id
          WHERE a.section_id = ? AND a.period_id = ?
          GROUP BY sub.student_id
      ),
      OverallStats AS (
          SELECT 
              sub.student_id,
              SUM(CASE WHEN sub.status IN ('Submitted', 'Late') THEN sub.score ELSE 0 END) as total_earned,
              SUM(a.max_score) as total_possible
          FROM assignments a
          JOIN submissions sub ON a.id = sub.assignment_id
          WHERE a.section_id = ?
          GROUP BY sub.student_id
      )
      SELECT 
          s.id AS student_id,
          s.full_name,
          COALESCE(p.period_earned, 0) AS period_earned,
          COALESCE(p.period_possible, 0) AS period_possible,
          CASE 
            WHEN COALESCE(p.period_possible, 0) > 0 
            THEN ROUND((p.period_earned * 100.0) / p.period_possible, 2) 
            ELSE 0.0 
          END AS period_average,
          CASE 
            WHEN COALESCE(o.total_possible, 0) > 0 
            THEN ROUND((o.total_earned * 100.0) / o.total_possible, 2) 
            ELSE 0.0 
          END AS overall_average
      FROM enrollments e
      INNER JOIN students s ON e.student_id = s.id
      LEFT JOIN PeriodStats p ON p.student_id = s.id
      LEFT JOIN OverallStats o ON o.student_id = s.id
      WHERE e.section_id = ?
    ''',
      [sectionId, periodId, sectionId, sectionId],
    );
  }

  Future<Map<String, dynamic>> getClassPerformanceSummary(
    String sectionId,
  ) async {
    final db = await _dbService.database;

    // Period-based averages — division-by-zero guarded
    final List<Map<String, dynamic>> periodAverages = await db.rawQuery(
      '''
      SELECT 
        a.period_id,
        ap.name as period_name,
        ap.order_index,
        ROUND(
          CASE WHEN SUM(a.max_score) > 0 
          THEN (SUM(CASE WHEN sub.status IN ('Submitted', 'Late') THEN sub.score ELSE 0 END) * 100.0) / SUM(a.max_score)
          ELSE 0.0 END,
        2) AS class_period_average
      FROM assignments a
      INNER JOIN submissions sub ON sub.assignment_id = a.id
      INNER JOIN academic_periods ap ON a.period_id = ap.id
      WHERE a.section_id = ? AND sub.status IN ('Submitted', 'Late')
      GROUP BY a.period_id
      ORDER BY ap.order_index ASC
    ''',
      [sectionId],
    );

    // Cumulative average — division-by-zero guarded (was missing before)
    final List<Map<String, dynamic>> totalCumulative = await db.rawQuery(
      '''
      SELECT 
        ROUND(
          CASE WHEN SUM(a.max_score) > 0
          THEN (SUM(CASE WHEN sub.status IN ('Submitted', 'Late') THEN sub.score ELSE 0 END) * 100.0) / SUM(a.max_score)
          ELSE 0.0 END,
        2) AS cumulative_class_average
      FROM assignments a
      INNER JOIN submissions sub ON sub.assignment_id = a.id
      WHERE a.section_id = ? AND sub.status IN ('Submitted', 'Late')
    ''',
      [sectionId],
    );

    double overall = 0.0;
    if (totalCumulative.isNotEmpty &&
        totalCumulative.first['cumulative_class_average'] != null) {
      overall = (totalCumulative.first['cumulative_class_average'] as num)
          .toDouble();
    }

    return {'periods': periodAverages, 'overall_cumulative': overall};
  }

  // 6. Delete Assignment and Cascade Submissions
  Future<void> deleteAssignment(String assignmentId) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'submissions',
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
      );
      await txn.delete(
        'assignments',
        where: 'id = ?',
        whereArgs: [assignmentId],
      );
    });
  }

  Future<void> assignPeriodToTask(String assignmentId, String periodId) async {
    final db = await _dbService.database;
    await db.update(
      'assignments',
      {'period_id': periodId},
      where: 'id = ?',
      whereArgs: [assignmentId],
    );
  }
}
