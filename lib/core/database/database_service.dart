import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:teacheros/core/database/encryption_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('teacher_os.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbDir = await getApplicationDocumentsDirectory();
    final path = join(dbDir.path, filePath);

    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isDesktop) {
      sqflite_ffi.sqfliteFfiInit();
      return await sqflite_ffi.databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 13, // v11: topic-based QB  v12: choices column
          onCreate: _createDB,
          onConfigure: _onConfigure,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    final password = await EncryptionService.getDatabasePassword();
    return await openDatabase(
      path,
      version: 13, // v11: topic-based QB  v12: choices column
      password: password,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration from Version 1 -> 2
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(students)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('middle_name')) {
        await db.execute('ALTER TABLE students ADD COLUMN middle_name TEXT;');
      }
      if (!columnNames.contains('birthdate')) {
        await db.execute('ALTER TABLE students ADD COLUMN birthdate TEXT;');
      }
    }

    // Migration from Version 2 -> 3
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grading_frameworks (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, is_default INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS academic_periods (
          id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, name TEXT NOT NULL, order_index INTEGER NOT NULL,
          FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transmutation_rules (
          id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, min_grade REAL NOT NULL, max_grade REAL NOT NULL,
          transmuted_value REAL NOT NULL, descriptor TEXT,
          FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO grading_frameworks (id, name, description, is_default) 
        VALUES ('default_framework', 'Legacy Config', 'Auto-generated during update', 1)
      ''');

      var cols = await db.rawQuery('PRAGMA table_info(sections)');
      var colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('framework_id')) {
        await db.execute(
          "ALTER TABLE sections ADD COLUMN framework_id TEXT NOT NULL DEFAULT 'default_framework';",
        );
      }

      cols = await db.rawQuery('PRAGMA table_info(grade_categories)');
      colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('framework_id')) {
        await db.execute(
          "ALTER TABLE grade_categories ADD COLUMN framework_id TEXT NOT NULL DEFAULT 'default_framework';",
        );
      }

      cols = await db.rawQuery('PRAGMA table_info(assessments)');
      colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('period_id')) {
        await db.execute(
          "ALTER TABLE assessments ADD COLUMN period_id TEXT NOT NULL DEFAULT 'default_period';",
        );
      }
      if (!colNames.contains('category_id')) {
        await db.execute(
          "ALTER TABLE assessments ADD COLUMN category_id TEXT NOT NULL DEFAULT 'default_category';",
        );
      }
      if (!colNames.contains('order_index')) {
        await db.execute(
          "ALTER TABLE assessments ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0;",
        );
      }
    }

    // Migration from Version 3 -> 4
    if (oldVersion < 4) {
      final cols = await db.rawQuery('PRAGMA table_info(grade_categories)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('order_index')) {
        await db.execute(
          "ALTER TABLE grade_categories ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0;",
        );
      }
      if (!colNames.contains('weight_percentage')) {
        await db.execute(
          "ALTER TABLE grade_categories ADD COLUMN weight_percentage REAL NOT NULL DEFAULT 0.0;",
        );
        if (colNames.contains('weight')) {
          await db.execute(
            "UPDATE grade_categories SET weight_percentage = weight;",
          );
        }
      }
    }

    // Migration from Version 4 -> 5
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE grade_categories_new (
          id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, name TEXT NOT NULL,
          weight_percentage REAL NOT NULL, order_index INTEGER NOT NULL,
          FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO grade_categories_new (id, framework_id, name, weight_percentage, order_index)
        SELECT id, framework_id, name, weight_percentage, order_index FROM grade_categories
      ''');
      await db.execute('DROP TABLE grade_categories');
      await db.execute(
        'ALTER TABLE grade_categories_new RENAME TO grade_categories',
      );
    }

    // Migration from Version 5 -> 6
    if (oldVersion < 6) {
      final cols = await db.rawQuery('PRAGMA table_info(grade_items)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('section_id')) {
        await db.execute(
          "ALTER TABLE grade_items ADD COLUMN section_id TEXT NOT NULL DEFAULT ''",
        );
      }
    }

    // Migration from Version 6 -> 7
    if (oldVersion < 7) {
      final cols = await db.rawQuery('PRAGMA table_info(assignments)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('period_id')) {
        await db.execute(
          "ALTER TABLE assignments ADD COLUMN period_id TEXT DEFAULT NULL",
        );
        final sections = await db.rawQuery(
          'SELECT DISTINCT s.id, s.framework_id FROM assignments a JOIN sections s ON a.section_id = s.id',
        );
        for (var section in sections) {
          final sectionId = section['id'] as String;
          final frameworkId = section['framework_id'] as String;
          final assignments = await db.rawQuery(
            'SELECT id, quarter_number FROM assignments WHERE section_id = ?',
            [sectionId],
          );
          for (var assignment in assignments) {
            final assignmentId = assignment['id'] as String;
            final quarterNum = assignment['quarter_number'] as int?;
            if (quarterNum != null && quarterNum > 0) {
              final period = await db.rawQuery(
                'SELECT id FROM academic_periods WHERE framework_id = ? AND order_index = ?',
                [frameworkId, quarterNum - 1],
              );
              if (period.isNotEmpty) {
                await db.update(
                  'assignments',
                  {'period_id': period.first['id'] as String},
                  where: 'id = ?',
                  whereArgs: [assignmentId],
                );
              }
            }
          }
        }
      }
    }

    // Migration from Version 7 -> 8
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE submissions_new (
          id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT NOT NULL, status TEXT NOT NULL, score REAL,
          FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
      final cols = await db.rawQuery('PRAGMA table_info(submissions)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (colNames.contains('assessment_id')) {
        await db.execute(
          'INSERT INTO submissions_new (id, assignment_id, student_id, status, score) SELECT id, assessment_id, student_id, status, score FROM submissions',
        );
      } else if (colNames.contains('assignment_id')) {
        await db.execute(
          'INSERT INTO submissions_new (id, assignment_id, student_id, status, score) SELECT id, assignment_id, student_id, status, score FROM submissions',
        );
      }
      await db.execute('DROP TABLE submissions');
      await db.execute('ALTER TABLE submissions_new RENAME TO submissions');
    }

    // Migration from Version 8 -> 9
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grade_subcategories (
          id TEXT PRIMARY KEY, category_id TEXT NOT NULL, name TEXT NOT NULL, weight_percentage REAL, order_index INTEGER NOT NULL,
          FOREIGN KEY (category_id) REFERENCES grade_categories (id) ON DELETE CASCADE
        )
      ''');
      final itemCols = await db.rawQuery('PRAGMA table_info(grade_items)');
      final itemColNames = itemCols.map((c) => c['name'] as String).toList();
      if (!itemColNames.contains('subcategory_id')) {
        await db.execute(
          'ALTER TABLE grade_items ADD COLUMN subcategory_id TEXT;',
        );
      }
      await _seedDepEdDefaultsIfNeeded(db);
    }

    // MIGRATION TRACK 9 -> 10: Append missing period_id field to grade_items
    if (oldVersion < 10) {
      final cols = await db.rawQuery('PRAGMA table_info(grade_items)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('period_id')) {
        await db.execute('ALTER TABLE grade_items ADD COLUMN period_id TEXT;');
      }
    }

    // MIGRATION 10 -> 11: Topic-based question bank (school-year-independent)
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS question_topics (
          id         TEXT PRIMARY KEY,
          title      TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS question_bank_v2 (
          id            TEXT PRIMARY KEY,
          topic_id      TEXT NOT NULL,
          type          TEXT NOT NULL,
          question_text TEXT NOT NULL,
          metadata_tags TEXT,
          choices       TEXT,
          FOREIGN KEY (topic_id) REFERENCES question_topics (id) ON DELETE CASCADE
        )
      ''');
      // Migrate any existing rows from the old assessment-bound table
      final oldRows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM question_bank',
      );
      final oldCount = (oldRows.first['c'] as int?) ?? 0;
      if (oldCount > 0) {
        const migId = 'topic_migrated_legacy';
        await db.execute(
          "INSERT OR IGNORE INTO question_topics (id, title, created_at) "
          "VALUES ('$migId', 'Migrated Questions', '${DateTime.now().toIso8601String()}')",
        );
        await db.rawInsert(
          'INSERT OR IGNORE INTO question_bank_v2 '
          '(id, topic_id, type, question_text, metadata_tags) '
          "SELECT id, '$migId', type, question_text, metadata_tags FROM question_bank",
        );
      }
    }

    // MIGRATION 11 -> 12: Add choices column to question_bank_v2
    if (oldVersion < 12) {
      final cols = await db.rawQuery('PRAGMA table_info(question_bank_v2)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('choices')) {
        await db.execute(
          'ALTER TABLE question_bank_v2 ADD COLUMN choices TEXT;',
        );
      }
    }

    if (oldVersion < 13) {
      await db.execute('''
        UPDATE question_bank_v2
        SET choices = '["True","False"]'
        WHERE type = 'True/False' AND (choices IS NULL OR choices = '')
      ''');
    }
  }

  Future<void> _seedDepEdDefaultsIfNeeded(
    Database db, {
    String frameworkId = 'default_framework',
  }) async {
    final existing = await db.query(
      'grade_categories',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    const wwId = 'cat_ww_default';
    const ptId = 'cat_pt_default';
    const qaId = 'cat_qa_default';

    await db.insert('grade_categories', {
      'id': wwId,
      'framework_id': frameworkId,
      'name': 'Written Works',
      'weight_percentage': 25.0,
      'order_index': 0,
    });
    await db.insert('grade_categories', {
      'id': ptId,
      'framework_id': frameworkId,
      'name': 'Performance Tasks',
      'weight_percentage': 50.0,
      'order_index': 1,
    });
    await db.insert('grade_categories', {
      'id': qaId,
      'framework_id': frameworkId,
      'name': 'Quarterly Assessment',
      'weight_percentage': 25.0,
      'order_index': 2,
    });

    const wwSubs = [
      'Quizzes',
      'Unit Tests',
      'Seatworks',
      'Assignments',
      'Written Examinations',
    ];
    for (var i = 0; i < wwSubs.length; i++) {
      await db.insert('grade_subcategories', {
        'id': 'sub_ww_default_\$i',
        'category_id': wwId,
        'name': wwSubs[i],
        'weight_percentage': null,
        'order_index': i,
      });
    }
    const ptSubs = [
      'Projects',
      'Presentations',
      'Demonstrations',
      'Experiments',
      'Portfolios',
      'Role-Playing Activities',
    ];
    for (var i = 0; i < ptSubs.length; i++) {
      await db.insert('grade_subcategories', {
        'id': 'sub_pt_default_\$i',
        'category_id': ptId,
        'name': ptSubs[i],
        'weight_percentage': null,
        'order_index': i,
      });
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE school_years (id TEXT PRIMARY KEY, name TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE grading_frameworks (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, is_default INTEGER DEFAULT 0)',
    );
    await db.insert('grading_frameworks', {
      'id': 'default_framework',
      'name': 'DepEd MATATAG Curriculum Framework',
      'description':
          'Default Philippine K-12 grading structure — Written Works 25%, Performance Tasks 50%, Quarterly Assessment 25%.',
      'is_default': 1,
    });
    await db.execute('''
      CREATE TABLE sections (
        id TEXT PRIMARY KEY, school_year_id TEXT NOT NULL, framework_id TEXT NOT NULL, grade_level INTEGER NOT NULL, name TEXT NOT NULL, adviser_name TEXT, is_archived INTEGER DEFAULT 0,  
        FOREIGN KEY (school_year_id) REFERENCES school_years (id) ON DELETE CASCADE,
        FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute(
      'CREATE TABLE academic_periods (id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, name TEXT NOT NULL, order_index INTEGER NOT NULL, FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE subjects (id TEXT PRIMARY KEY, section_id TEXT NOT NULL, name TEXT NOT NULL, schedule_time TEXT, FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE students (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, middle_name TEXT, birthdate TEXT, gender TEXT, photo_path TEXT, parent_contact TEXT, emergency_contact TEXT, address TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE enrollments (student_id TEXT NOT NULL, section_id TEXT NOT NULL, PRIMARY KEY (student_id, section_id), FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE, FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE attendance (id TEXT PRIMARY KEY, student_id TEXT NOT NULL, section_id TEXT NOT NULL, date TEXT NOT NULL, status TEXT NOT NULL, FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE, FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE, UNIQUE(student_id, section_id, date))',
    );
    await db.execute(
      'CREATE TABLE grade_categories (id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, name TEXT NOT NULL, weight_percentage REAL NOT NULL, order_index INTEGER NOT NULL, FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE grade_subcategories (id TEXT PRIMARY KEY, category_id TEXT NOT NULL, name TEXT NOT NULL, weight_percentage REAL, order_index INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES grade_categories (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE transmutation_rules (id TEXT PRIMARY KEY, framework_id TEXT NOT NULL, min_grade REAL NOT NULL, max_grade REAL NOT NULL, transmuted_value REAL NOT NULL, descriptor TEXT, FOREIGN KEY (framework_id) REFERENCES grading_frameworks (id) ON DELETE CASCADE)',
    );

    // Fresh installs support period_id configuration directly
    await db.execute('''
      CREATE TABLE grade_items (
        id TEXT PRIMARY KEY, section_id TEXT NOT NULL, category_id TEXT NOT NULL, subcategory_id TEXT, period_id TEXT, title TEXT NOT NULL, max_points INTEGER NOT NULL, date_created TEXT NOT NULL,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES grade_categories (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES grade_subcategories (id) ON DELETE SET NULL,
        FOREIGN KEY (period_id) REFERENCES academic_periods (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE TABLE student_grades (student_id TEXT NOT NULL, item_id TEXT NOT NULL, score_achieved REAL NOT NULL, PRIMARY KEY (student_id, item_id), FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE, FOREIGN KEY (item_id) REFERENCES grade_items (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE assessments (id TEXT PRIMARY KEY, section_id TEXT NOT NULL, period_id TEXT NOT NULL, category_id TEXT NOT NULL, title TEXT NOT NULL, due_date TEXT NOT NULL, max_score INTEGER NOT NULL, order_index INTEGER NOT NULL, FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE, FOREIGN KEY (period_id) REFERENCES academic_periods (id) ON DELETE RESTRICT, FOREIGN KEY (category_id) REFERENCES grade_categories (id) ON DELETE RESTRICT)',
    );
    await db.execute(
      'CREATE TABLE question_bank (id TEXT PRIMARY KEY, assessment_id TEXT NOT NULL, type TEXT NOT NULL, question_text TEXT NOT NULL, metadata_tags TEXT, FOREIGN KEY (assessment_id) REFERENCES assessments (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE question_topics (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE question_bank_v2 (id TEXT PRIMARY KEY, topic_id TEXT NOT NULL, type TEXT NOT NULL, question_text TEXT NOT NULL, metadata_tags TEXT, choices TEXT, FOREIGN KEY (topic_id) REFERENCES question_topics (id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE calendar_events (id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL, event_date TEXT NOT NULL, description TEXT)',
    );
    await db.execute(
      'CREATE TABLE assignments (id TEXT PRIMARY KEY, section_id TEXT NOT NULL, title TEXT NOT NULL, type TEXT NOT NULL, due_date TEXT NOT NULL, max_score INTEGER NOT NULL, period_id TEXT, FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE, FOREIGN KEY (period_id) REFERENCES academic_periods (id) ON DELETE SET NULL)',
    );
    await db.execute(
      'CREATE TABLE submissions (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT NOT NULL, status TEXT NOT NULL, score REAL, FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE, FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE)',
    );

    await _seedDepEdDefaultsIfNeeded(db);
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> resetAndReinit() async {
    await close();
    _database = await _initDB('teacher_os.db');
  }
}
