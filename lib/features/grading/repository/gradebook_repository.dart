import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import 'framework_repository.dart';

class GradebookRepository {
  final _dbService = DatabaseService.instance;
  final _uuid = const Uuid();
  final _frameworkRepo = FrameworkRepository();

  // ==========================================================================
  // 1. CURRICULUM STRUCTURE (READ-ONLY HERE)
  // ==========================================================================

  /// [READ] The full category/subcategory tree for a class section, via
  /// whichever framework that section is currently assigned to.
  Future<List<CategoryWithSubcategories>> getGradeStructure(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    final sectionResult = await db.query(
      'sections',
      columns: ['framework_id'],
      where: 'id = ?',
      whereArgs: [sectionId],
      limit: 1,
    );
    final frameworkId = sectionResult.isNotEmpty
        ? sectionResult.first['framework_id'] as String
        : 'default_framework';
    return _frameworkRepo.getCategoriesWithSubcategories(frameworkId);
  }

  // ==========================================================================
  // 2. GRADE ITEMS CRUD (Individual Tasks: e.g., "Quiz 1", "Seatwork #3")
  // ==========================================================================

  /// [CREATE] Add a new graded task under a category, subcategory, and explicit period.
  Future<void> createGradeItem({
    required String id,
    required String sectionId,
    required String categoryId,
    String? subcategoryId,
    required String periodId,
    required String title,
    required int maxPoints,
    required String dateCreated,
  }) async {
    final db = await _dbService.database;
    await db.insert('grade_items', {
      'id': id,
      'section_id': sectionId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'period_id': periodId,
      'title': title,
      'max_points': maxPoints,
      'date_created': dateCreated,
    });
  }

  /// [READ] Get all tasks belonging to a specific category and period for one section.
  Future<List<Map<String, dynamic>>> getGradeItems({
    required String sectionId,
    required String categoryId,
    required String periodId,
  }) async {
    final db = await _dbService.database;
    return await db.query(
      'grade_items',
      where: 'section_id = ? AND category_id = ? AND period_id = ?',
      whereArgs: [sectionId, categoryId, periodId],
      orderBy: 'date_created ASC',
    );
  }

  /// [READ] Returns all students enrolled in a section.
  /// Each row includes: id, first_name, last_name, full_name, gender.
  Future<List<Map<String, dynamic>>> getEnrolledStudentsForSection(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT CAST(s.id AS TEXT) AS id, s.full_name, s.gender
      FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      WHERE e.section_id = ?
      ORDER BY s.full_name ASC
      ''',
      [sectionId],
    );
  }

  /// [READ] Get ALL grade items for a section across all categories and periods.
  /// Used by the Excel export to build the full task list.
  /// Each row includes: id, title, max_points, category_id, subcategory_id,
  /// period_id, and category_name (joined from grade_categories).
  Future<List<Map<String, dynamic>>> getAllGradeItemsForSection(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT
        gi.id,
        gi.title,
        gi.max_points,
        gi.category_id,
        gi.subcategory_id,
        gi.period_id,
        gi.date_created,
        gc.name AS category_name
      FROM grade_items gi
      LEFT JOIN grade_categories gc ON gc.id = gi.category_id
      WHERE gi.section_id = ?
      ORDER BY gc.order_index ASC, gi.date_created ASC
      ''',
      [sectionId],
    );
  }

  /// [READ] Returns a nested score map ready for the Excel export service:
  ///   { studentId: { itemId: scoreAchieved } }
  /// Only rows with a non-null score are included so the export can distinguish
  /// "not submitted" (missing key) from "scored zero".
  Future<Map<String, Map<String, double>>> getStudentScoresMap(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        CAST(s.id AS TEXT) AS student_id,
        sg.item_id,
        sg.score_achieved
      FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      INNER JOIN grade_items gi ON gi.section_id = e.section_id
      INNER JOIN student_grades sg ON sg.student_id = s.id AND sg.item_id = gi.id
      WHERE e.section_id = ?
      ''',
      [sectionId],
    );

    final Map<String, Map<String, double>> result = {};
    for (final row in rows) {
      final studentId = row['student_id'] as String;
      final itemId = row['item_id'] as String;
      final score = (row['score_achieved'] as num?)?.toDouble() ?? 0.0;
      result.putIfAbsent(studentId, () => {})[itemId] = score;
    }
    return result;
  }

  /// [UPDATE] Modify an existing task's meta parameters.
  Future<void> updateGradeItem(
    String itemId,
    String title,
    int maxPoints,
  ) async {
    final db = await _dbService.database;
    await db.update(
      'grade_items',
      {'title': title, 'max_points': maxPoints},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// [DELETE] Removes a task.
  Future<void> deleteGradeItem(String itemId) async {
    final db = await _dbService.database;
    await db.delete('grade_items', where: 'id = ?', whereArgs: [itemId]);
  }

  // ==========================================================================
  // 3. STUDENT GRADES CRUD (Scores Transaction Matrix)
  // ==========================================================================

  /// [READ] Fetches the complete grading spreadsheet matrix data filtered by period
  /// and updates selection bindings to safely extract [gi.period_id].
  Future<List<Map<String, dynamic>>> getGradeMatrixData({
    required String sectionId,
    required String categoryId,
    required String periodId,
    String? subcategoryId,
  }) async {
    final db = await _dbService.database;

    final subcategoryClause = subcategoryId != null
        ? 'AND gi.subcategory_id = ?'
        : '';
    final joinArgs = subcategoryId != null
        ? [categoryId, subcategoryId, periodId]
        : [categoryId, periodId];

    return await db.rawQuery(
      '''
      SELECT 
        s.id AS student_id,
        s.full_name,
        gi.id AS item_id,
        gi.title AS item_title,
        gi.max_points,
        gi.period_id,
        sg.score_achieved
      FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      LEFT JOIN grade_items gi ON gi.section_id = e.section_id 
        AND gi.category_id = ? $subcategoryClause AND gi.period_id = ?
      LEFT JOIN student_grades sg ON sg.student_id = s.id AND sg.item_id = gi.id
      WHERE e.section_id = ?
      ORDER BY s.full_name ASC, gi.date_created ASC
    ''',
      [...joinArgs, sectionId],
    );
  }

  /// [CREATE / UPDATE] Bulk records scores inputted by the teacher from the UI grid array.
  Future<void> saveStudentScores(List<Map<String, dynamic>> scoresList) async {
    final db = await _dbService.database;
    final batch = db.batch();

    for (var scoreRow in scoresList) {
      batch.execute(
        '''
        INSERT OR REPLACE INTO student_grades (student_id, item_id, score_achieved)
        VALUES (?, ?, ?)
      ''',
        [
          scoreRow['student_id'],
          scoreRow['item_id'],
          scoreRow['score_achieved'],
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  // ==========================================================================
  // 4. ASSIGNMENT → GRADEBOOK SYNC
  // ==========================================================================

  Future<({String categoryId, String? subcategoryId})> getAssignmentSyncTarget(
    String sectionId,
  ) async {
    final db = await _dbService.database;

    final sectionResult = await db.query(
      'sections',
      columns: ['framework_id'],
      where: 'id = ?',
      whereArgs: [sectionId],
      limit: 1,
    );
    final frameworkId = sectionResult.isNotEmpty
        ? sectionResult.first['framework_id'] as String
        : 'default_framework';

    final subMatch = await _frameworkRepo.findSubcategoryByName(
      frameworkId,
      'Assignments',
    );
    if (subMatch != null) {
      return (categoryId: subMatch.categoryId, subcategoryId: subMatch.id);
    }

    final categories = await _frameworkRepo.getCategories(frameworkId);
    for (final cat in categories) {
      final normalized = cat.name.trim().toLowerCase();
      if (normalized == 'assignments' || normalized == 'assignment') {
        return (categoryId: cat.id, subcategoryId: null);
      }
    }

    final fallbackId = _uuid.v4();
    await db.insert('grade_categories', {
      'id': fallbackId,
      'framework_id': frameworkId,
      'name': 'Assignments',
      'weight_percentage': 0.0,
      'order_index': categories.length,
    });
    return (categoryId: fallbackId, subcategoryId: null);
  }

  /// Syncs submission context directly tracking its active period.
  Future<void> syncSubmissionToGradebook({
    required String sectionId,
    required String assignmentId,
    required String studentId,
    required double? score,
    required int maxScore,
    required String assignmentTitle,
    String? periodId,
  }) async {
    final db = await _dbService.database;

    final target = await getAssignmentSyncTarget(sectionId);

    // If periodId isn't passed down explicitly, resolve it from the parent assignment context
    String? finalPeriodId = periodId;
    if (finalPeriodId == null) {
      final assignRes = await db.query(
        'assignments',
        columns: ['period_id'],
        where: 'id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      if (assignRes.isNotEmpty) {
        finalPeriodId = assignRes.first['period_id'] as String?;
      }
    }

    final existing = await db.query(
      'grade_items',
      where: 'id = ?',
      whereArgs: [assignmentId],
    );

    if (existing.isEmpty) {
      await db.insert('grade_items', {
        'id': assignmentId,
        'section_id': sectionId,
        'category_id': target.categoryId,
        'subcategory_id': target.subcategoryId,
        'period_id': finalPeriodId,
        'title': assignmentTitle,
        'max_points': maxScore,
        'date_created': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'grade_items',
        {
          'title': assignmentTitle,
          'max_points': maxScore,
          'category_id': target.categoryId,
          'subcategory_id': target.subcategoryId,
          'period_id': finalPeriodId,
        },
        where: 'id = ?',
        whereArgs: [assignmentId],
      );
    }

    if (score == null) {
      await db.delete(
        'student_grades',
        where: 'student_id = ? AND item_id = ?',
        whereArgs: [studentId, assignmentId],
      );
    } else {
      await db.execute(
        '''
        INSERT OR REPLACE INTO student_grades (student_id, item_id, score_achieved)
        VALUES (?, ?, ?)
        ''',
        [studentId, assignmentId, score],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getOverallScoresForSection(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT s.id AS student_id, s.full_name,
        SUM(COALESCE(sg.score_achieved,0)) AS total_achieved,
        SUM(COALESCE(gi.max_points,0)) AS total_possible
      FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      LEFT JOIN grade_items gi ON gi.section_id = e.section_id
      LEFT JOIN student_grades sg ON sg.student_id = s.id AND sg.item_id = gi.id
      WHERE e.section_id = ?
      GROUP BY s.id, s.full_name
    ''',
      [sectionId],
    );
  }
}
