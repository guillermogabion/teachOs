import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../student_sis/models/student_model.dart';

class EnrollmentRepository {
  final _dbService = DatabaseService.instance;

  // Get all students currently assigned to a specific class
  Future<List<Student>> getStudentsInSection(String sectionId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT s.* FROM students s
      INNER JOIN enrollments e ON s.id = e.student_id
      WHERE e.section_id = ?
      ORDER BY s.full_name ASC
    ''',
      [sectionId],
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // Get all students NOT in this class yet (for the selection picker screen)
  Future<List<Student>> getStudentsAvailableForSection(String sectionId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM students 
      WHERE id NOT IN (SELECT student_id FROM enrollments WHERE section_id = ?)
      ORDER BY full_name ASC
    ''',
      [sectionId],
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // Future<List<Map<String, dynamic>>> searchUnenrolledStudents(
  //   String sectionId,
  //   String searchQuery,
  // ) async {
  //   final db = await _dbService.database;

  //   // If the search is empty, return an empty list or the first 10 unenrolled students
  //   if (searchQuery.trim().isEmpty) return [];

  //   return await db.rawQuery(
  //     '''
  //     SELECT id, full_name
  //     FROM students
  //     WHERE id NOT IN (SELECT student_id FROM enrollments WHERE section_id = ?)
  //     AND full_name LIKE ?
  //     ORDER BY full_name ASC
  //     LIMIT 15 -- Limit results to keep the UI snappy
  //   ''',
  //     [sectionId, '%$searchQuery%'],
  //   );
  // }

  // // Batch insert multiple student assignments at once
  Future<void> enrollStudents(String sectionId, List<int> studentIds) async {
    final db = await _dbService.database; // Your database instance

    final batch = db.batch();
    for (final id in studentIds) {
      batch.insert('enrollments', {
        'section_id': sectionId,
        'student_id': id, // This will now correctly insert the integer ID
      });
    }
    await batch.commit(noResult: true);
  }

  // Remove a student from a specific class roster
  // Remove a student from a specific class roster
  Future<void> unenrollStudent(String sectionId, int studentId) async {
    final db = await _dbService.database;
    await db.delete(
      'enrollments',
      where: 'section_id = ? AND student_id = ?',
      whereArgs: [sectionId, studentId], // ✅ int works natively in SQLite
    );
  }
  // --- ENROLLMENT METHODS ---

  /// Dynamically searches for students NOT currently enrolled in the specified class.
  Future<List<Map<String, dynamic>>> searchUnenrolledStudents(
    String sectionId,
    String searchQuery,
  ) async {
    final db = await _dbService.database;

    // If the search is empty, return an empty list or the first 10 unenrolled students
    if (searchQuery.trim().isEmpty) return [];

    return await db.rawQuery(
      '''
      SELECT id, full_name 
      FROM students 
      WHERE id NOT IN (SELECT student_id FROM enrollments WHERE section_id = ?)
      AND full_name LIKE ?
      ORDER BY full_name ASC
      LIMIT 15 -- Limit results to keep the UI snappy
    ''',
      [sectionId, '%$searchQuery%'],
    );
  }

  /// Enrolls the selected student into the class
  Future<void> enrollStudent(String sectionId, String studentId) async {
    final db = await _dbService.database;
    await db.insert('enrollments', {
      'student_id': studentId,
      'section_id': sectionId,
    });
  }
}
