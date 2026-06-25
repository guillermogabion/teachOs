import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';

// --- Data Models ---

class GradingFramework {
  String id;
  String name;
  String? description;
  bool isDefault;

  GradingFramework({
    required this.id,
    required this.name,
    this.description,
    this.isDefault = false,
  });

  factory GradingFramework.fromMap(Map<String, dynamic> m) => GradingFramework(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    isDefault: (m['is_default'] as int? ?? 0) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'is_default': isDefault ? 1 : 0,
  };
}

class GradeCategory {
  String id;
  String frameworkId;
  String name;
  double weightPercentage;
  int orderIndex;

  GradeCategory({
    required this.id,
    required this.frameworkId,
    required this.name,
    required this.weightPercentage,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'framework_id': frameworkId,
    'name': name,
    'weight_percentage': weightPercentage,
    'order_index': orderIndex,
  };
}

/// A sub-type within a category — e.g. "Quizzes" or "Unit Tests" under
/// "Written Works". [weightPercentage] is optional: leave it null to use the
/// subcategory purely as an organizational label (items still pool together
/// under the parent category's weight). Fill it in — on every sibling, so
/// they sum to 100 — to instead split the parent's weight proportionally
/// across subcategories.
class GradeSubcategory {
  String id;
  String categoryId;
  String name;
  double? weightPercentage;
  int orderIndex;

  GradeSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.weightPercentage,
    required this.orderIndex,
  });

  factory GradeSubcategory.fromMap(Map<String, dynamic> m) => GradeSubcategory(
    id: m['id'] as String,
    categoryId: m['category_id'] as String,
    name: m['name'] as String,
    weightPercentage: (m['weight_percentage'] as num?)?.toDouble(),
    orderIndex: m['order_index'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'name': name,
    'weight_percentage': weightPercentage,
    'order_index': orderIndex,
  };
}

/// Bundles a category with its subcategories — the shape the Class
/// Gradebook's dynamic grid (and anything else that needs the whole tree)
/// works with, instead of fetching each level separately.
class CategoryWithSubcategories {
  final GradeCategory category;
  final List<GradeSubcategory> subcategories;

  CategoryWithSubcategories({
    required this.category,
    required this.subcategories,
  });

  /// True once every subcategory has its own explicit weight (and the
  /// teacher has therefore opted into per-subcategory weighting). An empty
  /// list, or any subcategory still missing a weight, means pooled/grouping
  /// mode — all items under the category count equally.
  bool get isSubcategoryWeighted =>
      subcategories.isNotEmpty &&
      subcategories.every((s) => s.weightPercentage != null);
}

class AcademicPeriod {
  String id;
  String frameworkId;
  String name;
  int orderIndex;

  AcademicPeriod({
    required this.id,
    required this.frameworkId,
    required this.name,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'framework_id': frameworkId,
    'name': name,
    'order_index': orderIndex,
  };
}

// --- Repository ---
class FrameworkRepository {
  final _uuid = const Uuid();

  // ------------------ Transmutation Rules ------------------
  Future<List<TransmutationRule>> getTransmutations(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'transmutation_rules',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
      orderBy: 'min_grade DESC',
    );
    return maps.map((m) => TransmutationRule.fromMap(m)).toList();
  }

  Future<void> saveTransmutation(TransmutationRule rule) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'transmutation_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTransmutation(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('transmutation_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransmutationsForFramework(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      'transmutation_rules',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
    );
  }

  /// Return the transmuted value for [percent] according to rules for [frameworkId].
  /// Returns null when no matching rule is found.
  Future<double?> transmute(String frameworkId, double percent) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM transmutation_rules
      WHERE framework_id = ? AND ? >= min_grade AND ? <= max_grade
      LIMIT 1
    ''',
      [frameworkId, percent, percent],
    );
    if (maps.isEmpty) return null;
    final rule = TransmutationRule.fromMap(maps.first);
    return rule.transmutedValue;
  }
  // ==========================================================================
  // FRAMEWORKS — the reusable templates a class can pick from. This layer is
  // what makes two classes' grading configurations genuinely independent:
  // each section just references one framework_id, and switching it only
  // affects that section.
  // ==========================================================================

  Future<List<GradingFramework>> getFrameworks() async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'grading_frameworks',
      orderBy: 'is_default DESC, name ASC',
    );
    return maps.map(GradingFramework.fromMap).toList();
  }

  Future<GradingFramework?> getFrameworkById(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'grading_frameworks',
      where: 'id = ?',
      whereArgs: [frameworkId],
    );
    if (maps.isEmpty) return null;
    return GradingFramework.fromMap(maps.first);
  }

  Future<String> createFramework({
    required String name,
    String? description,
  }) async {
    final db = await DatabaseService.instance.database;
    final id = _uuid.v4();
    await db.insert('grading_frameworks', {
      'id': id,
      'name': name,
      'description': description,
      'is_default': 0,
    });
    return id;
  }

  /// Deletes a framework and — via cascading foreign keys — everything
  /// scoped under it: categories, subcategories, terms, and transmutation
  /// rules. Refuses to delete the built-in default framework, since the
  /// rest of the app falls back to 'default_framework' whenever a section
  /// has nothing else configured.
  Future<void> deleteFramework(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final existing = await db.query(
      'grading_frameworks',
      where: 'id = ?',
      whereArgs: [frameworkId],
      limit: 1,
    );
    if (existing.isEmpty) return;

    final isDefault = (existing.first['is_default'] as int? ?? 0) == 1;
    if (isDefault) {
      throw StateError('The default framework cannot be deleted.');
    }

    await db.delete(
      'grading_frameworks',
      where: 'id = ?',
      whereArgs: [frameworkId],
    );
  }

  /// How many classes currently rely on this framework — worth surfacing
  /// before a teacher edits or deletes it, since changes apply to every
  /// section using it.
  Future<int> countSectionsUsingFramework(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sections WHERE framework_id = ?',
      [frameworkId],
    );
    return result.first['total'] as int? ?? 0;
  }

  /// How many recorded student scores would be permanently wiped if this
  /// framework were deleted. Deleting a framework cascades through its
  /// categories down to every grade_item filed under them — including items
  /// for sections that have since switched to a *different* framework, since
  /// the item itself still points at the old category. This is what makes a
  /// framework delete worth a stronger warning than just "X classes use it".
  Future<int> countGradeEntriesForFramework(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM student_grades sg
      INNER JOIN grade_items gi ON gi.id = sg.item_id
      INNER JOIN grade_categories gc ON gc.id = gi.category_id
      WHERE gc.framework_id = ?
    ''',
      [frameworkId],
    );
    return result.first['total'] as int? ?? 0;
  }

  Future<String?> getFrameworkIdForSection(String sectionId) async {
    final db = await DatabaseService.instance.database;
    final result = await db.query(
      'sections',
      columns: ['framework_id'],
      where: 'id = ?',
      whereArgs: [sectionId],
    );
    if (result.isEmpty) return null;
    return result.first['framework_id'] as String?;
  }

  /// Lets a class switch which framework it follows, independently of every
  /// other class — the whole point of this model.
  Future<void> assignFrameworkToSection({
    required String sectionId,
    required String frameworkId,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'sections',
      {'framework_id': frameworkId},
      where: 'id = ?',
      whereArgs: [sectionId],
    );
  }

  // ==========================================================================
  // GRADE CATEGORIES — weights, scoped to a framework so every section on
  // that framework shares the same configuration, and sections on a
  // different framework are unaffected.
  // ==========================================================================

  Future<List<GradeCategory>> getCategories(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'grade_categories',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
      orderBy: 'order_index ASC',
    );
    return maps
        .map(
          (m) => GradeCategory(
            id: m['id'] as String,
            frameworkId: m['framework_id'] as String,
            name: m['name'] as String,
            weightPercentage: (m['weight_percentage'] as num).toDouble(),
            orderIndex: m['order_index'] as int,
          ),
        )
        .toList();
  }

  Future<void> saveCategory(GradeCategory category) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'grade_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Persists a full reordering in one batch — call after a drag-and-drop
  /// reorder so order_index survives a reload.
  Future<void> saveCategoryOrder(List<GradeCategory> orderedCategories) async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    for (var i = 0; i < orderedCategories.length; i++) {
      orderedCategories[i].orderIndex = i;
      batch.insert(
        'grade_categories',
        orderedCategories[i].toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      'grade_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  // ==========================================================================
  // SUBCATEGORIES — optional sub-types within a category (e.g. Quizzes / Unit
  // Tests / Seatworks under "Written Works"). See GradeSubcategory for the
  // pooled-vs-weighted mode rules.
  // ==========================================================================

  Future<List<GradeSubcategory>> getSubcategories(String categoryId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'grade_subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'order_index ASC',
    );
    return maps.map(GradeSubcategory.fromMap).toList();
  }

  Future<void> saveSubcategory(GradeSubcategory subcategory) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'grade_subcategories',
      subcategory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSubcategory(String subcategoryId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      'grade_subcategories',
      where: 'id = ?',
      whereArgs: [subcategoryId],
    );
  }

  Future<void> saveSubcategoryOrder(
    List<GradeSubcategory> orderedSubcategories,
  ) async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    for (var i = 0; i < orderedSubcategories.length; i++) {
      orderedSubcategories[i].orderIndex = i;
      batch.insert(
        'grade_subcategories',
        orderedSubcategories[i].toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Categories for [frameworkId], each bundled with its subcategories —
  /// the shape the Class Gradebook's dynamic grid renders directly off of.
  Future<List<CategoryWithSubcategories>> getCategoriesWithSubcategories(
    String frameworkId,
  ) async {
    final categories = await getCategories(frameworkId);
    final result = <CategoryWithSubcategories>[];
    for (final cat in categories) {
      final subs = await getSubcategories(cat.id);
      result.add(CategoryWithSubcategories(category: cat, subcategories: subs));
    }
    return result;
  }

  /// Finds a subcategory by name anywhere inside [frameworkId], regardless
  /// of which parent category it sits under. Used by integrations — like the
  /// Assignment Dashboard — that sync into a named bucket (e.g.
  /// "Assignments") rather than a fixed category/subcategory id.
  Future<GradeSubcategory?> findSubcategoryByName(
    String frameworkId,
    String name,
  ) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.rawQuery(
      '''
      SELECT gs.* FROM grade_subcategories gs
      INNER JOIN grade_categories gc ON gc.id = gs.category_id
      WHERE gc.framework_id = ? AND LOWER(gs.name) = LOWER(?)
      LIMIT 1
    ''',
      [frameworkId, name],
    );
    if (maps.isEmpty) return null;
    return GradeSubcategory.fromMap(maps.first);
  }

  // ==========================================================================
  // ACADEMIC PERIODS — quarters/semesters, also scoped to a framework.
  // ==========================================================================

  Future<List<AcademicPeriod>> getPeriods(String frameworkId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'academic_periods',
      where: 'framework_id = ?',
      whereArgs: [frameworkId],
      orderBy: 'order_index ASC',
    );
    return maps
        .map(
          (m) => AcademicPeriod(
            id: m['id'] as String,
            frameworkId: m['framework_id'] as String,
            name: m['name'] as String,
            orderIndex: m['order_index'] as int,
          ),
        )
        .toList();
  }

  Future<void> savePeriod(AcademicPeriod period) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'academic_periods',
      period.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePeriod(String periodId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('academic_periods', where: 'id = ?', whereArgs: [periodId]);
  }

  Future<void> savePeriodOrder(List<AcademicPeriod> orderedPeriods) async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    for (var i = 0; i < orderedPeriods.length; i++) {
      orderedPeriods[i].orderIndex = i;
      batch.insert(
        'academic_periods',
        orderedPeriods[i].toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}

class TransmutationRule {
  String id;
  String frameworkId;
  double minGrade;
  double maxGrade;
  double transmutedValue;
  String? descriptor;

  TransmutationRule({
    required this.id,
    required this.frameworkId,
    required this.minGrade,
    required this.maxGrade,
    required this.transmutedValue,
    this.descriptor,
  });

  factory TransmutationRule.fromMap(Map<String, dynamic> m) =>
      TransmutationRule(
        id: m['id'] as String,
        frameworkId: m['framework_id'] as String,
        minGrade: (m['min_grade'] as num).toDouble(),
        maxGrade: (m['max_grade'] as num).toDouble(),
        transmutedValue: (m['transmuted_value'] as num).toDouble(),
        descriptor: m['descriptor'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'framework_id': frameworkId,
    'min_grade': minGrade,
    'max_grade': maxGrade,
    'transmuted_value': transmutedValue,
    'descriptor': descriptor,
  };

  /// Persists a full reordering in one batch for Academic Periods.
}
