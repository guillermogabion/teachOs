import '../../../core/database/database_service.dart';
import '../models/student_model.dart';

class StudentRepository {
  final _dbService = DatabaseService.instance;

  // 1. CREATE
  Future<void> insertStudent(Student student) async {
    final db = await _dbService.database;
    await db.insert('students', student.toMap());
  }

  // 2. READ (All)
  Future<List<Student>> getAllStudents() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      orderBy: 'full_name ASC',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // READ (Filtered)
  Future<List<Student>> getStudentsBySection(String sectionId) async {
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

  // 3. UPDATE
  Future<void> updateStudent(Student student) async {
    final db = await _dbService.database;
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  // 4. DELETE
  Future<int> deleteStudent(int id) async {
    final db = await _dbService.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Student>> checkPotentialDuplicates(
    String fullName,
    String contact,
  ) async {
    final db = await DatabaseService.instance.database;

    final trimmedName = fullName.trim();
    final trimmedContact = contact.trim();

    // Only check name (always required)
    // Only add contact to the match if it was actually supplied
    if (trimmedContact.isEmpty) {
      // No contact provided — match on name only
      final List<Map<String, dynamic>> maps = await db.query(
        'students',
        where: 'LOWER(full_name) = LOWER(?)',
        whereArgs: [trimmedName],
      );
      return maps.map((map) => Student.fromMap(map)).toList();
    }

    // Both supplied — require BOTH to match (not OR)
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'LOWER(full_name) = LOWER(?) AND parent_contact = ?',
      whereArgs: [trimmedName, trimmedContact],
    );

    return maps.map((map) => Student.fromMap(map)).toList();
  }
}
