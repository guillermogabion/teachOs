import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'repository/gradebook_repository.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const amberWarning = Color(0xFFD97706);
  static const redText = Color(0xFFDC2626);
}

// ─── Reusable Input Decoration ────────────────────────────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  final String categoryName;

  const GradeCategoryScreen({
    super.key,
    required this.sectionId,
    required this.categoryName,
  });

  @override
  State<GradeCategoryScreen> createState() => _GradeCategoryScreenState();
}

class _GradeCategoryScreenState extends State<GradeCategoryScreen> {
  final _gradeRepo = GradebookRepository();
  bool _isLoading = true;

  // State Maps
  final Map<String, String> _students = {};
  final Map<String, Map<String, dynamic>> _gradeItems = {};
  final Map<String, Map<String, double>> _scores = {};

  // Safely track uncommitted changes using a Map to overwrite duplicates
  final Map<String, Map<String, dynamic>> _pendingSavesMap = {};
  bool get _hasUnsavedChanges => _pendingSavesMap.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    setState(() => _isLoading = true);

    await _gradeRepo.saveGradeCategoryWeights(
      sectionId: widget.sectionId,
      weights: {widget.categoryName: 0.0},
    );

    final rawData = await _gradeRepo.getGradeMatrixData(
      sectionId: widget.sectionId,
      categoryName: widget.categoryName,
    );

    _students.clear();
    _gradeItems.clear();
    _scores.clear();
    _pendingSavesMap.clear();

    for (var row in rawData) {
      final sId = row['student_id'] as String;
      _students[sId] = row['full_name'] as String;

      if (!_scores.containsKey(sId)) {
        _scores[sId] = {};
      }

      final itemId = row['item_id'] as String?;
      if (itemId != null) {
        _gradeItems[itemId] = {
          'title': row['item_title'],
          'max_points': row['max_points'],
        };

        final score = row['score_achieved'] as double?;
        if (score != null) {
          _scores[sId]![itemId] = score;
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- CREATE NEW COLUMN MODAL ---
  Future<void> _showCreateTaskModal() async {
    final titleCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '100');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New ${widget.categoryName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _Brand.tealDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: _buildInputDecoration(
                labelText: 'Task Title (e.g., Seatwork 1)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: _buildInputDecoration(labelText: 'Max Points'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.tealMid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || pointsCtrl.text.isEmpty) return;

              final maxPts = int.tryParse(pointsCtrl.text);
              if (maxPts == null || maxPts <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter a valid number for Max Points.',
                    ),
                  ),
                );
                return;
              }

              try {
                final categoryId =
                    'CAT_${widget.sectionId}_${widget.categoryName}';
                await _gradeRepo.createGradeItem(
                  id: const Uuid().v4(),
                  categoryId: categoryId,
                  title: titleCtrl.text.trim(),
                  maxPoints: maxPts,
                  dateCreated: DateTime.now().toIso8601String(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  _initializeAndLoad();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: _Brand.redText,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // --- SAVE GRADES TO DATABASE ---
  Future<void> _commitGrades() async {
    FocusScope.of(context).unfocus();
    if (_pendingSavesMap.isEmpty) return;

    final payload = _pendingSavesMap.values.toList();
    await _gradeRepo.saveStudentScores(payload);

    setState(() => _pendingSavesMap.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grades saved securely.'),
          backgroundColor: _Brand.tealDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedItemIds = _gradeItems.keys.toList();
    final sortedStudentIds = _students.keys.toList()
      ..sort((a, b) => _students[a]!.compareTo(_students[b]!));

    // Locked Heights to prevent dynamic visual alignment snapping
    const double rowHeight = 56.0;
    const double headerHeight = 64.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.categoryName} Matrix',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _Brand.amberWarning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _commitGrades,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : _students.isEmpty
          ? const Center(
              child: Text(
                'No students enrolled in this class.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==========================================
                        // LEFT PANEL: Sticky Names
                        // ==========================================
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: DataTable(
                            dataRowMinHeight: rowHeight,
                            dataRowMaxHeight: rowHeight,
                            headingRowHeight: headerHeight,
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey.shade50,
                            ),
                            horizontalMargin: 16,
                            columnSpacing: 0,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Student Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
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
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        // ==========================================
                        // RIGHT PANEL: Scrollable Tasks & Scores
                        // ==========================================
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              dataRowMinHeight: rowHeight,
                              dataRowMaxHeight: rowHeight,
                              headingRowHeight: headerHeight,
                              headingRowColor: MaterialStateProperty.all(
                                _Brand.tealSurf,
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
                                ...sortedItemIds.map((itemId) {
                                  final item = _gradeItems[itemId]!;
                                  return DataColumn(
                                    label: Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: _Brand.tealDark,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Max: ${item['max_points']}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: _Brand.tealMid.withOpacity(
                                                0.8,
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
                                    'Average %',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _Brand.tealDark,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              rows: sortedStudentIds.map((sId) {
                                double totalAchieved = 0;
                                double totalPossible = 0;

                                final cells = sortedItemIds.map((itemId) {
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
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: score != null
                                              ? Colors.black87
                                              : Colors.black45,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: '--',
                                          hintStyle: TextStyle(
                                            color: Colors.black26,
                                          ),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final parsedValue = double.tryParse(
                                            value,
                                          );
                                          setState(() {
                                            if (parsedValue != null &&
                                                parsedValue <= maxPts) {
                                              _scores[sId]![itemId] =
                                                  parsedValue;
                                              _pendingSavesMap['${sId}_$itemId'] =
                                                  {
                                                    'student_id': sId,
                                                    'item_id': itemId,
                                                    'score_achieved':
                                                        parsedValue,
                                                  };
                                            } else if (value.isEmpty) {
                                              _scores[sId]!.remove(itemId);
                                              _pendingSavesMap['${sId}_$itemId'] =
                                                  {
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
                                                ? _Brand.teal
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
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskModal,
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'New ${widget.categoryName}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
