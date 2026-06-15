import 'dart:io';
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
      // Use FFI factory directly — no encryption on desktop
      return await sqflite_ffi.databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDB,
          onConfigure: _onConfigure,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    // Mobile path — encrypted with SQLCipher
    final password = await EncryptionService.getDatabasePassword();
    return await openDatabase(
      path,
      version: 2,
      password: password,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
  }

  /// Enable Foreign Key Support in SQLite
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. School Year Table (Handles your Archiving Logic via is_active)
    await db.execute('''
      CREATE TABLE school_years (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Sections Table
    await db.execute('''
      CREATE TABLE sections (
        id TEXT PRIMARY KEY,
        school_year_id TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        name TEXT NOT NULL,
        adviser_name TEXT,
        is_archived INTEGER DEFAULT 0,  
        FOREIGN KEY (school_year_id) REFERENCES school_years (id) ON DELETE CASCADE
      )
    ''');

    // 3. Subjects Table
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        section_id TEXT NOT NULL,
        name TEXT NOT NULL,
        schedule_time TEXT,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // 4. Students Table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        middle_name TEXT,      -- Added here for new installs
        birthdate TEXT,        -- Added here for new installs
        gender TEXT,
        photo_path TEXT,
        parent_contact TEXT,
        emergency_contact TEXT,
        address TEXT,
        notes TEXT
      )
    ''');

    // 5. Enrollment Junction Table (Maps students to sections)
    await db.execute('''
      CREATE TABLE enrollments (
        student_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        PRIMARY KEY (student_id, section_id),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // 6. Attendance Table
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        section_id TEXT NOT NULL, 
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE,
        UNIQUE(student_id, section_id, date) 
      );
    ''');

    // 7. Gradebook Categories Table (Weights & Formulas)
    await db.execute('''
      CREATE TABLE grade_categories (
        id TEXT PRIMARY KEY,
        section_id TEXT NOT NULL,
        name TEXT NOT NULL, 
        weight REAL NOT NULL DEFAULT 0.0, 
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // 8. Gradebook Items Table (Individual tasks)
    await db.execute('''
      CREATE TABLE grade_items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title TEXT NOT NULL,
        max_points INTEGER NOT NULL,
        date_created TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES grade_categories (id) ON DELETE CASCADE
      )
    ''');

    // 9. Student Grades Transaction Table
    await db.execute('''
      CREATE TABLE student_grades (
        student_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        score_achieved REAL NOT NULL,
        PRIMARY KEY (student_id, item_id),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES grade_items (id) ON DELETE CASCADE
      )
    ''');

    // 10. Assessment Templates Table
    await db.execute('''
      CREATE TABLE assessments (
        id TEXT PRIMARY KEY,
        section_id TEXT NOT NULL,
        title TEXT NOT NULL,
        difficulty_tag TEXT NOT NULL, 
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // 11. Question Bank Table
    await db.execute('''
      CREATE TABLE question_bank (
        id TEXT PRIMARY KEY,
        assessment_id TEXT NOT NULL,
        type TEXT NOT NULL, 
        question_text TEXT NOT NULL,
        metadata_tags TEXT, 
        FOREIGN KEY (assessment_id) REFERENCES assessments (id) ON DELETE CASCADE
      )
    ''');

    // 12. Calendar Events
    await db.execute('''
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL, 
        event_date TEXT NOT NULL, 
        description TEXT
      )
    ''');

    // 13. Assignments Table (UPDATED: Added quarter_number & Foreign Key)
    await db.execute('''
      CREATE TABLE assignments (
        id TEXT PRIMARY KEY,
        section_id TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL, 
        due_date TEXT NOT NULL,
        max_score INTEGER NOT NULL,
        quarter_number INTEGER NOT NULL DEFAULT 1, -- Dynamic quarter configuration
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // 14. Submissions Table (UPDATED: Added explicit Foreign Keys for cascading integrity)
    await db.execute('''
      CREATE TABLE submissions (
        id TEXT PRIMARY KEY,
        assignment_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        status TEXT NOT NULL, 
        score REAL,
        FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null; // ← critical: null it out so getter reinitializes fresh
    }
  }

  Future<void> resetAndReinit() async {
    await close(); // closes and nulls _database
    _database = await _initDB('teacher_os.db'); // fresh open
  }
}
