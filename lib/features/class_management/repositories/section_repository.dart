import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../models/section_model.dart';

class SectionRepository {
  final _dbService = DatabaseService.instance;

  // Helper method matching your system logic
  String _calculateCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    return now.month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  // 1. READ (Active Only)
  Future<List<Section>> getActiveSections() async {
    final db = await _dbService.database;
    final currentSY = _calculateCurrentSchoolYear();

    final List<Map<String, dynamic>> maps = await db.query(
      'sections',
      where: 'school_year_id = ?',
      whereArgs: [currentSY],
      orderBy: 'grade_level ASC, name ASC',
    );
    return List.generate(maps.length, (i) => Section.fromMap(maps[i]));
  }

  // 2. READ (Archived Only)
  Future<List<Section>> getArchivedSections() async {
    final db = await _dbService.database;
    final currentSY = _calculateCurrentSchoolYear();

    final List<Map<String, dynamic>> maps = await db.query(
      'sections',
      where: 'school_year_id != ?',
      whereArgs: [currentSY],
      // Sort by newest school year down to oldest
      orderBy: 'school_year_id DESC, grade_level ASC, name ASC',
    );
    return List.generate(maps.length, (i) => Section.fromMap(maps[i]));
  }

  // CREATE (Remains dynamic as previously set up)
  Future<void> insertSection(Section section) async {
    final db = await _dbService.database;
    final data = section.toMap();

    await db.insert('school_years', {
      'id': section.schoolYearId,
      'name': 'School Year ${section.schoolYearId}',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    if (section.id.isEmpty) {
      data['id'] = 'SEC_${DateTime.now().microsecondsSinceEpoch}';
    }
    await db.insert('sections', data);
  }

  // UPDATE & DELETE remain unchanged...
  Future<void> updateSection(Section section) async {
    final db = await _dbService.database;
    await db.update(
      'sections',
      section.toMap(),
      where: 'id = ?',
      whereArgs: [section.id],
    );
  }

  Future<void> deleteSection(String id) async {
    final db = await _dbService.database;
    await db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getGenderCounts(String sectionId) async {
    // Get your database instance (adjust this to match your setup, e.g., using DatabaseService)
    final db = await _dbService.database;

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
    SELECT 
      COUNT(CASE WHEN s.gender = 'Male' THEN 1 END) as males,
      COUNT(CASE WHEN s.gender = 'Female' THEN 1 END) as females
    FROM enrollments e
    INNER JOIN students s ON e.student_id = s.id
    WHERE e.section_id = ?
  ''',
      [sectionId],
    );

    if (result.isNotEmpty) {
      return {
        'males': result.first['males'] as int? ?? 0,
        'females': result.first['females'] as int? ?? 0,
      };
    }
    return {'males': 0, 'females': 0};
  }
}
