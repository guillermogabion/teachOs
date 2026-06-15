import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';

class GradebookRepository {
  final _dbService = DatabaseService.instance;

  // ==========================================================================
  // 1. GRADE CATEGORIES CRUD (Weights & Formulas)
  // ==========================================================================

  /// [READ] Get all grading categories and their configured weights for a class section
  Future<List<Map<String, dynamic>>> getGradeCategories(
    String sectionId,
  ) async {
    final db = await _dbService.database;
    return await db.query(
      'grade_categories',
      where: 'section_id = ?',
      whereArgs: [sectionId],
    );
  }

  /// [CREATE / UPDATE] Bulk upsert weights. If they don't exist, create them. If they do, update them.
  Future<void> saveGradeCategoryWeights({
    required String sectionId,
    required Map<String, double> weights, // e.g., {'Quiz': 0.20, 'Exam': 0.40}
  }) async {
    final db = await _dbService.database;
    final batch = db.batch();

    weights.forEach((categoryName, weightValue) {
      batch.execute(
        '''
        INSERT OR REPLACE INTO grade_categories (id, section_id, name, weight)
        VALUES (?, ?, ?, ?)
      ''',
        [
          'CAT_${sectionId}_$categoryName', // Reliable unique composite string ID
          sectionId,
          categoryName,
          weightValue,
        ],
      );
    });

    await batch.commit(noResult: true);
  }

  // ==========================================================================
  // 2. GRADE ITEMS CRUD (Individual Tasks: e.g., "Quiz 1", "Seatwork #3")
  // ==========================================================================

  /// [CREATE] Add a new graded task under a category
  Future<void> createGradeItem({
    required String id,
    required String categoryId,
    required String title,
    required int maxPoints,
    required String dateCreated,
  }) async {
    final db = await _dbService.database;
    await db.insert('grade_items', {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'max_points': maxPoints,
      'date_created': dateCreated,
    });
  }

  /// [READ] Get all tasks belonging to a specific category configuration
  Future<List<Map<String, dynamic>>> getGradeItemsByCategory(
    String categoryId,
  ) async {
    final db = await _dbService.database;
    return await db.query(
      'grade_items',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'date_created ASC',
    );
  }

  /// [UPDATE] Modify an existing task's meta parameters
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

  /// [DELETE] Removes a task. Foreign Key constraints automatically cascade delete all student scores attached.
  Future<void> deleteGradeItem(String itemId) async {
    final db = await _dbService.database;
    await db.delete('grade_items', where: 'id = ?', whereArgs: [itemId]);
  }

  // ==========================================================================
  // 3. STUDENT GRADES CRUD (Scores Transaction Matrix)
  // ==========================================================================

  /// [READ] Fetches the complete grading spreadsheet matrix data for a specific category.
  /// Guarantees all enrolled students show up, even if they have no records yet (via LEFT JOIN).
  Future<List<Map<String, dynamic>>> getGradeMatrixData({
    required String sectionId,
    required String categoryName,
  }) async {
    final db = await _dbService.database;
    return await db.rawQuery(
      '''
      SELECT 
        s.id AS student_id,
        s.full_name,
        gi.id AS item_id,
        gi.title AS item_title,
        gi.max_points,
        sg.score_achieved
      FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      INNER JOIN grade_categories gc ON e.section_id = gc.section_id
      LEFT JOIN grade_items gi ON gc.id = gi.category_id
      LEFT JOIN student_grades sg ON s.id = sg.student_id AND gi.id = sg.item_id
      WHERE e.section_id = ? AND gc.name = ?
      ORDER BY s.full_name ASC, gi.date_created ASC
    ''',
      [sectionId, categoryName],
    );
  }

  /// [CREATE / UPDATE] Bulk records scores inputted by the teacher from the UI grid array
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
}
