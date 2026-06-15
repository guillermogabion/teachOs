import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'repository/gradebook_repository.dart';

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
        title: Text('New ${widget.categoryName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task Title (e.g., Seatwork 1)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Points',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
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
                      backgroundColor: Colors.red,
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
    // Dismiss the keyboard safely before saving
    FocusScope.of(context).unfocus();

    if (_pendingSavesMap.isEmpty) return;

    final payload = _pendingSavesMap.values.toList();
    await _gradeRepo.saveStudentScores(payload);

    setState(() => _pendingSavesMap.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grades saved securely.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedItemIds = _gradeItems.keys.toList();
    final sortedStudentIds = _students.keys.toList()
      ..sort((a, b) => _students[a]!.compareTo(_students[b]!));

    // Lock Heights to prevent alignment snapping
    const double rowHeight = 60.0;
    const double headerHeight = 70.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.categoryName} Matrix'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 8.0, 8.0, 8.0),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                ),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Changes'),
                onPressed: _commitGrades,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(child: Text('No students enrolled in this class.'))
          : Column(
              children: [
                Expanded(
                  // Master vertical scroll for both panels
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
                                color: Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                          ),
                          child: DataTable(
                            dataRowMinHeight: rowHeight,
                            dataRowMaxHeight: rowHeight,
                            headingRowHeight: headerHeight,
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey.shade100,
                            ),
                            horizontalMargin: 16,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Student Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: sortedStudentIds.map((sId) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    // Ensure text never wraps to two lines, breaking the sync
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        _students[sId] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
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
                        // RIGHT PANEL: Scrollable Tasks & Scores (INLINE EDITING)
                        // ==========================================
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              dataRowMinHeight: rowHeight,
                              dataRowMaxHeight: rowHeight,
                              headingRowHeight: headerHeight,
                              headingRowColor: MaterialStateProperty.all(
                                Colors.teal.shade50,
                              ),
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                                verticalInside: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              columns: [
                                ...sortedItemIds.map((itemId) {
                                  final item = _gradeItems[itemId]!;
                                  return DataColumn(
                                    label: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal.shade900,
                                          ),
                                        ),
                                        Text(
                                          'Max: ${item['max_points']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                DataColumn(
                                  label: Text(
                                    'Average %',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
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
                                      width: 80,
                                      alignment: Alignment.center,
                                      color: score != null
                                          ? Colors.transparent
                                          : Colors.grey.shade50,
                                      child: TextFormField(
                                        // INLINE EDITING ENABLED HERE
                                        initialValue: score != null
                                            ? score.toStringAsFixed(1)
                                            : '',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: score != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: score != null
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: '--',
                                          isDense: true,
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
                                            fontWeight: FontWeight.bold,
                                            color: avg >= 75
                                                ? Colors.teal
                                                : Colors
                                                      .red, // Colors based on passing grade
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
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('New ${widget.categoryName}'),
      ),
    );
  }
}
