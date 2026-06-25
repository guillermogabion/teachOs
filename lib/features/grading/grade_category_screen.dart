import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'repository/gradebook_repository.dart';
import '../assignments/repository/assignment_repository.dart'; // Required to fetch periods

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const amberWarning = Color(0xFFD97706);
  static const redText = Color(0xFFA32D2D);
  static const redSurf = Color(0xFFFCEBEB);
  static const bgSurface = Color(0xFFF9FAFB);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
}

// ─── Reusable Input Decoration ────────────────────────────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
    ),
  );
}

class GradeCategoryScreen extends StatefulWidget {
  final String sectionId;
  final String categoryId;
  final String categoryName;
  final String? subcategoryId;
  final String? subcategoryName;

  const GradeCategoryScreen({
    super.key,
    required this.sectionId,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
  });

  @override
  State<GradeCategoryScreen> createState() => _GradeCategoryScreenState();
}

class _GradeCategoryScreenState extends State<GradeCategoryScreen> {
  final _gradeRepo = GradebookRepository();
  final _assignRepo = AssignmentRepository(); // Added for periods

  bool _isLoading = true;

  // Period / Term State
  List<Map<String, dynamic>> _periods = [];
  String _selectedPeriodId = '';

  // State Maps
  final Map<String, String> _students = {};
  final Map<String, Map<String, dynamic>> _gradeItems = {};
  final Map<String, Map<String, double>> _scores = {};

  final Map<String, Map<String, dynamic>> _pendingSavesMap = {};
  bool get _hasUnsavedChanges => _pendingSavesMap.isNotEmpty;

  String get _displayName => widget.subcategoryName ?? widget.categoryName;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    setState(() => _isLoading = true);

    // 1. Fetch available periods for this section's framework
    final periodsList = await _assignRepo.getAvailablePeriods(widget.sectionId);

    // 2. Resolve which period should be selected before fetching the matrix.
    if (mounted) {
      _periods = periodsList;
      if (_periods.isNotEmpty &&
          !_periods.any((p) => p['id'] == _selectedPeriodId)) {
        _selectedPeriodId = _periods.first['id'] as String;
      } else if (_periods.isEmpty) {
        _selectedPeriodId = '';
      }
    }

    // 3. Always fetch the roster. getGradeMatrixData is built FROM students
    // INNER JOIN enrollments, with grade_items/scores only LEFT JOINed in —
    // so every enrolled student comes back regardless of whether a period
    // or any grade items exist yet. Bailing out early here whenever periods
    // were empty was what made the whole student list vanish; an empty
    // _selectedPeriodId just means no item columns will match, not that the
    // roster fetch should be skipped.
    final rawData = await _gradeRepo.getGradeMatrixData(
      sectionId: widget.sectionId,
      categoryId: widget.categoryId,
      subcategoryId: widget.subcategoryId,
      periodId: _selectedPeriodId,
    );

    _students.clear();
    _gradeItems.clear();
    _scores.clear();
    _pendingSavesMap.clear();

    for (var row in rawData) {
      final sId = row['student_id']?.toString() ?? '';
      final fullName = row['full_name']?.toString() ?? '';
      _students[sId] = fullName;

      if (!_scores.containsKey(sId)) {
        _scores[sId] = {};
      }

      final itemId = row['item_id']?.toString();
      if (itemId != null && itemId.isNotEmpty) {
        _gradeItems[itemId] = {
          'title': row['item_title']?.toString() ?? '',
          'max_points': row['max_points'],
          'period_id': row['period_id']?.toString() ?? '',
        };

        final scoreRaw = row['score_achieved'];
        final score = scoreRaw is int
            ? scoreRaw.toDouble()
            : scoreRaw as double?;

        if (score != null) {
          _scores[sId]![itemId] = score;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? _Brand.redText : _Brand.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  // --- CREATE NEW COLUMN MODAL ---
  Future<void> _showCreateTaskModal() async {
    if (_periods.isEmpty) {
      _showSnackBar(
        'Set up at least one academic period in Curriculum Settings before adding grade items.',
        isError: true,
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '100');
    String modalPeriodId =
        _selectedPeriodId; // Default to currently viewed period

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'New $_displayName',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: _Brand.charcoal,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a new grading item to the matrix.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _Brand.mutedText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _buildInputDecoration(
                    labelText: 'Task Title (e.g., Seatwork 1)',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _buildInputDecoration(
                          labelText: 'Max Points',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: modalPeriodId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _Brand.charcoal,
                        ),
                        decoration: _buildInputDecoration(
                          labelText: 'Term / Period',
                        ),
                        items: _periods
                            .map(
                              (p) => DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(p['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => modalPeriodId = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _Brand.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _Brand.tealDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || pointsCtrl.text.isEmpty) return;

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final maxPts = int.tryParse(pointsCtrl.text);
                if (maxPts == null || maxPts <= 0) {
                  _showSnackBar(
                    'Please enter a valid number for Max Points.',
                    isError: true,
                  );
                  return;
                }

                try {
                  await _gradeRepo.createGradeItem(
                    id: const Uuid().v4(),
                    sectionId: widget.sectionId,
                    categoryId: widget.categoryId,
                    subcategoryId: widget.subcategoryId,
                    periodId: modalPeriodId, // Passed the selected Term
                    title: titleCtrl.text.trim(),
                    maxPoints: maxPts,
                    dateCreated: DateTime.now().toIso8601String(),
                  );

                  if (mounted) {
                    navigator.pop();
                    // If the created task belongs to a different period, jump to it
                    if (modalPeriodId != _selectedPeriodId) {
                      setState(() => _selectedPeriodId = modalPeriodId);
                    }
                    _initializeAndLoad();
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: _Brand.redText,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Create Task',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commitGrades() async {
    FocusScope.of(context).unfocus();
    if (_pendingSavesMap.isEmpty) return;

    final payload = _pendingSavesMap.values.toList();
    await _gradeRepo.saveStudentScores(payload);

    setState(() => _pendingSavesMap.clear());

    if (mounted) {
      _showSnackBar('Grades saved securely.');
    }
  }

  Future<void> _deleteGradeItem(String itemId) async {
    final item = _gradeItems[itemId];
    if (item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Column?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _Brand.charcoal,
          ),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: _Brand.mutedText,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'This will permanently delete '),
              TextSpan(
                text: '"${item['title']}"',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _Brand.charcoal,
                ),
              ),
              const TextSpan(
                text:
                    ' and all student scores recorded under it. This cannot be undone.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _Brand.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _Brand.redText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _gradeRepo.deleteGradeItem(itemId);
      if (mounted) {
        _showSnackBar('"${item['title']}" deleted.');
        _initializeAndLoad();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bgSurface, // Matched Dashboard BG
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                // Term / Period Filter Row (Matches Dashboard)
                if (_periods.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _periods.map((p) {
                          final periodId = p['id'] as String;
                          final isSelected = _selectedPeriodId == periodId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(p['name'] as String),
                              selected: isSelected,
                              selectedColor: _Brand.tealSurf,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? _Brand.teal.withOpacity(0.4)
                                    : Colors.grey.shade200,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? _Brand.tealDark
                                    : _Brand.charcoal,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedPeriodId = periodId);
                                  _initializeAndLoad();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),

                // Main Matrix Content
                Expanded(
                  child: _students.isEmpty
                      ? _buildEmptyState()
                      : _buildMatrix(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _Brand.tealMid,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: _showCreateTaskModal,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'New $_displayName',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
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
        onPressed: () {
          // If returning with unsaved changes, prompt first or auto-save depending on UX choice
          Navigator.pop(context);
        },
      ),
      title: Text(
        widget.subcategoryName != null
            ? '${widget.categoryName} › ${widget.subcategoryName}'
            : widget.categoryName,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _Brand.charcoal,
          fontSize: 17,
          letterSpacing: -0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      ),
      actions: [
        if (_hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.amberWarning,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text(
                'Save',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: _commitGrades,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.group_off_rounded,
                color: _Brand.tealMid,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No students enrolled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'There are no students enrolled in this class to grade yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Matrix View ────────────────────────────────────────────────────────────

  Widget _buildMatrix() {
    // Filter columns by the Selected Period
    final filteredItemIds = _gradeItems.keys
        .where((id) => _gradeItems[id]!['period_id'] == _selectedPeriodId)
        .toList();

    final sortedStudentIds = _students.keys.toList()
      ..sort((a, b) => _students[a]!.compareTo(_students[b]!));

    const double rowHeight = 56.0;
    const double headerHeight = 64.0;

    return Container(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: Sticky Names
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
            ),
            child: DataTable(
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              headingRowHeight: headerHeight,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              horizontalMargin: 16,
              columnSpacing: 0,
              columns: const [
                DataColumn(
                  label: Text(
                    'Student Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _Brand.charcoal,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              rows: sortedStudentIds.map((sId) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          _students[sId] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: _Brand.charcoal,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // RIGHT PANEL: Scrollable Tasks & Scores
          Expanded(
            child: filteredItemIds.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _periods.isEmpty
                            ? 'No academic periods are set up yet for this curriculum. Add one in Curriculum Settings, then tap "New $_displayName" to start grading.'
                            : 'No $_displayName recorded for this term.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _Brand.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: rowHeight,
                      dataRowMaxHeight: rowHeight,
                      headingRowHeight: headerHeight,
                      headingRowColor: WidgetStateProperty.all(
                        _Brand.tealSurf.withOpacity(0.4),
                      ),
                      horizontalMargin: 12,
                      columnSpacing: 16,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                        verticalInside: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                      ),
                      columns: [
                        ...filteredItemIds.map((itemId) {
                          final item = _gradeItems[itemId]!;
                          return DataColumn(
                            label: SizedBox(
                              width: 64,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        item['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _Brand.tealDark,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          '/${item['max_points']}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _deleteGradeItem(itemId),
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _Brand.redSurf,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: _Brand.redText.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 10,
                                          color: _Brand.redText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const DataColumn(
                          label: Text(
                            'Term Avg %',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _Brand.charcoal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      rows: sortedStudentIds.map((sId) {
                        double totalAchieved = 0;
                        double totalPossible = 0;

                        final cells = filteredItemIds.map((itemId) {
                          final maxPts =
                              _gradeItems[itemId]!['max_points'] as int;
                          final score = _scores[sId]?[itemId];

                          if (score != null) {
                            totalAchieved += score;
                            totalPossible += maxPts;
                          }

                          return DataCell(
                            Container(
                              width: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: score != null
                                    ? Colors.transparent
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextFormField(
                                initialValue: score != null
                                    ? score.toStringAsFixed(1)
                                    : '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: score != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: score != null
                                      ? Colors.black87
                                      : Colors.black45,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '--',
                                  hintStyle: TextStyle(color: Colors.black26),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  final parsedValue = double.tryParse(value);
                                  setState(() {
                                    if (parsedValue != null &&
                                        parsedValue <= maxPts) {
                                      _scores[sId]![itemId] = parsedValue;
                                      _pendingSavesMap['${sId}_$itemId'] = {
                                        'student_id': sId,
                                        'item_id': itemId,
                                        'score_achieved': parsedValue,
                                      };
                                    } else if (value.isEmpty) {
                                      _scores[sId]!.remove(itemId);
                                      _pendingSavesMap['${sId}_$itemId'] = {
                                        'student_id': sId,
                                        'item_id': itemId,
                                        'score_achieved': null,
                                      };
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList();

                        final avg = totalPossible > 0
                            ? (totalAchieved / totalPossible) * 100
                            : 0.0;

                        return DataRow(
                          cells: [
                            ...cells,
                            DataCell(
                              Center(
                                child: Text(
                                  '${avg.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: avg >= 75
                                        ? _Brand.tealDark
                                        : _Brand.redText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
