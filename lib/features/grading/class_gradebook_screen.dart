import 'package:flutter/material.dart';
import 'package:teacheros/features/class_management/models/section_model.dart';
import '../grading/framework_config_screen.dart';
import '../grading/repository/framework_repository.dart';
import '../grading/repository/gradebook_repository.dart';
import '../../services/excel_export_service.dart';
import './grade_category_screen.dart';
import './category_subcategories_screen.dart';

// ─── Brand palette (shared with GradebookScreen) ──────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
}
// ─────────────────────────────────────────────────────────────────────────────

class ClassGradebookScreen extends StatefulWidget {
  final Section section;

  const ClassGradebookScreen({super.key, required this.section});

  @override
  State<ClassGradebookScreen> createState() => _ClassGradebookScreenState();
}

class _ClassGradebookScreenState extends State<ClassGradebookScreen> {
  final _frameworkRepo = FrameworkRepository();
  final _gradeRepo = GradebookRepository();

  String? _frameworkId;
  List<CategoryWithSubcategories> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  // The grid below is entirely driven by whatever the assigned framework has
  // configured in Curriculum Settings — no hardcoded category list. Add,
  // rename, or remove a category (or its subcategories) there and this
  // screen reflects it on the next load.
  Future<void> _loadCurriculum() async {
    setState(() => _isLoading = true);
    final frameworkId =
        await _frameworkRepo.getFrameworkIdForSection(widget.section.id) ??
        'default_framework';
    final categories = await _frameworkRepo.getCategoriesWithSubcategories(
      frameworkId,
    );
    if (mounted) {
      setState(() {
        _frameworkId = frameworkId;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  void _navigateToCategory(CategoryWithSubcategories entry) {
    if (entry.subcategories.isEmpty) {
      // No subcategories configured for this category — items pool
      // directly under it, so skip straight to the scoring matrix.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GradeCategoryScreen(
            sectionId: widget.section.id,
            categoryId: entry.category.id,
            categoryName: entry.category.name,
          ),
        ),
      ).then((_) => _loadCurriculum());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategorySubcategoriesScreen(
            sectionId: widget.section.id,
            categoryEntry: entry,
          ),
        ),
      ).then((_) => _loadCurriculum());
    }
  }

  // "Formulas" opens the weight configuration for whichever grading
  // framework this section is assigned to — not a per-section weight set,
  // since two sections can share or diverge on that independently.
  Future<void> _navigateToWeights(BuildContext context) async {
    final frameworkId =
        _frameworkId ??
        await _frameworkRepo.getFrameworkIdForSection(widget.section.id) ??
        'default_framework';
    final framework = await _frameworkRepo.getFrameworkById(frameworkId);

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FrameworkConfigScreen(
          frameworkId: frameworkId,
          frameworkName: framework?.name ?? widget.section.name,
        ),
      ),
    ).then((_) => _loadCurriculum());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                Expanded(
                  child: _categories.isEmpty
                      ? _buildEmptyState(context)
                      : _buildGrid(),
                ),
                _buildExportDock(context),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 17,
            color: Colors.black54,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.section.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Grade ${widget.section.gradeLevel} · Gradebook',
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calculate_rounded,
                color: _Brand.tealMid,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No grading components yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This class\'s curriculum framework has no categories configured yet. Add components like Written Works or Performance Tasks first.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _navigateToWeights(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Configure Curriculum'),
              style: FilledButton.styleFrom(backgroundColor: _Brand.tealDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _categories.length + 1, // +1 for the Formulas card
      itemBuilder: (context, index) {
        if (index == _categories.length) {
          return _buildSubFeatureCard(
            'Formulas',
            Icons.calculate_rounded,
            () => _navigateToWeights(context),
          );
        }
        final entry = _categories[index];
        return _buildSubFeatureCard(
          entry.category.name,
          _iconForCategory(entry.category.name, index),
          () => _navigateToCategory(entry),
          subtitle: '${entry.category.weightPercentage.toStringAsFixed(0)}%',
        );
      },
    );
  }

  static const List<IconData> _fallbackIcons = [
    Icons.folder_open_rounded,
    Icons.bar_chart_rounded,
    Icons.fact_check_rounded,
    Icons.star_rounded,
  ];

  IconData _iconForCategory(String name, int index) {
    final lower = name.toLowerCase();
    if (lower.contains('written')) return Icons.edit_note_rounded;
    if (lower.contains('performance')) return Icons.theater_comedy_rounded;
    if (lower.contains('quarterly') ||
        lower.contains('exam') ||
        lower.contains('assessment')) {
      return Icons.workspace_premium_rounded;
    }
    if (lower.contains('quiz')) return Icons.timer_rounded;
    if (lower.contains('project')) return Icons.assignment_rounded;
    if (lower.contains('seatwork')) return Icons.menu_book_rounded;
    if (lower.contains('assignment')) {
      return Icons.assignment_turned_in_rounded;
    }
    return _fallbackIcons[index % _fallbackIcons.length];
  }

  // ── Export Dock ────────────────────────────────────────────────────────────

  Widget _buildExportDock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export PDF'),
              onPressed: () {},
              style: OutlinedButton.styleFrom(foregroundColor: _Brand.tealDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.table_view, size: 18),
              label: const Text('Export Excel'),
              onPressed: () => _exportGrades(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.tealMid,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportGrades(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating E-Class Record... Please wait.'),
      ),
    );

    try {
      // ==========================================================
      // 1. METADATA
      // ==========================================================
      final sectionName = widget.section.name;
      const subjectName = 'Subject'; // TODO: Section has no subject field yet
      final gradeLevel = widget.section.gradeLevel.toString();
      final schoolYear = widget.section.schoolYearId;
      const teacherName = 'Teacher Name'; // TODO: replace with real value

      // ==========================================================
      // 2. STUDENTS
      // ==========================================================
      final List<Map<String, dynamic>> allStudents = await _gradeRepo
          .getEnrolledStudentsForSection(widget.section.id);

      // ==========================================================
      // 3. TASKS
      // ==========================================================
      final List<Map<String, dynamic>> allTasks = await _gradeRepo
          .getAllGradeItemsForSection(widget.section.id);

      // ==========================================================
      // 4. SCORES
      // ==========================================================
      final Map<String, Map<String, double>> studentScores = await _gradeRepo
          .getStudentScoresMap(widget.section.id);

      // ==========================================================
      // 5. CATEGORIES (Map the already loaded _categories state)
      // ==========================================================
      final List<Map<String, dynamic>> mappedCategories = _categories.map((c) {
        return {'id': c.category.id, 'name': c.category.name};
      }).toList();

      if (!context.mounted) return;

      // ==========================================================
      // 6. EXPORT
      // ==========================================================
      final String? exportedFile =
          await ExcelExportService.exportTermGradesWithTemplate(
            context: context,
            sectionName: sectionName,
            teacherName: teacherName,
            subjectName: subjectName,
            schoolYear: schoolYear,
            gradeLevel: gradeLevel,
            allStudents: allStudents,
            allCategories:
                mappedCategories, // Passed cleanly to the new service
            allGradeItems: allTasks, // Passed cleanly to the new service
            studentScores: studentScores,
          );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (exportedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate template. Check your data.'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting grades: $e')));
    }
  }

  Widget _buildSubFeatureCard(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _Brand.tealSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Brand.teal.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: _Brand.tealDark),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _Brand.tealDark,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _Brand.tealMid.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
