import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Required for date formatting

// 1. Import your repository
import './repository/assignment_repository.dart';
// 2. Import your assignment dashboard to reuse the TrackingBottomSheet!
import 'assignment_dashboard_screen.dart';

// ============================================================================
// THEME & UI HELPERS
// ============================================================================
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const teal = Color(0xFF1D9E75);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
  static const bgSurface = Color(0xFFF9FAFB);
  static const amberWarning = Color(0xFFD97706);
  static const redText = Color(0xFFDC2626);
  static const blueAccent = Color(0xFF2563EB);
  static const graySurf = Color(0xFFECEFF1);
  static const grayText = Color(0xFF90A4AE);
}

// Added from the main dashboard to ensure consistent modal styling
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    suffix: suffix,
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

AppBar _buildBrandedAppBar({
  required BuildContext context,
  required String title,
  required String subtitle,
  List<Widget>? actions, // Added actions support
}) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: const IconThemeData(color: _Brand.charcoal),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _Brand.charcoal,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: _Brand.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    ),
    actions: actions,
  );
}

// ============================================================================
// SCREEN 1: LEGACY TASKS HUB (CLASS SELECTION)
// ============================================================================
class OldAssignmentScreen extends StatefulWidget {
  const OldAssignmentScreen({super.key});

  @override
  State<OldAssignmentScreen> createState() => _OldAssignmentScreenState();
}

class _OldAssignmentScreenState extends State<OldAssignmentScreen> {
  final _repo = AssignmentRepository();
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _viewingArchived = false; // Added archive state tracking

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);

    // Check archive status to determine which query to run
    final data = _viewingArchived
        ? await _repo.getArchivedClasses()
        : await _repo.getActiveClasses();

    if (mounted) {
      setState(() {
        _classes = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: _buildBrandedAppBar(
        context: context,
        title: _viewingArchived
            ? 'Archived Supplementary'
            : 'Supplementary Assignments',
        subtitle: _viewingArchived
            ? 'Read-only archived classes'
            : 'Unmapped Database Records',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: _viewingArchived
                  ? 'View Active Classes'
                  : 'Archived Classes',
              child: InkWell(
                onTap: () {
                  setState(() {
                    _viewingArchived = !_viewingArchived;
                  });
                  _loadClasses();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _viewingArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_outlined,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : _classes.isEmpty
          ? Center(
              child: Text(
                _viewingArchived
                    ? 'No archived classes found.'
                    : 'No active classes found.',
                style: const TextStyle(
                  color: _Brand.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final section = _classes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _viewingArchived
                            ? Colors.grey.shade100
                            : _Brand.graySurf,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _viewingArchived
                            ? Icons.class_rounded
                            : Icons.archive_outlined,
                        color: _viewingArchived
                            ? _Brand.mutedText
                            : _Brand.grayText,
                      ),
                    ),
                    title: Text(
                      section['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _Brand.charcoal,
                      ),
                    ),
                    subtitle: Text(
                      _viewingArchived
                          ? 'Read-Only Archive'
                          : 'View unmapped tasks',
                      style: const TextStyle(
                        color: _Brand.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.black38,
                            size: 20,
                          ),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (action) async {
                            if (action == 'archive') {
                              await _repo.toggleArchiveStatus(section['id'], 1);
                              _loadClasses();
                            } else if (action == 'restore') {
                              await _repo.toggleArchiveStatus(section['id'], 0);
                              _loadClasses();
                            }
                          },
                          itemBuilder: (context) => [
                            if (!_viewingArchived)
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text(
                                  'Archive Class',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (_viewingArchived)
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text(
                                  'Restore to Active',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LegacyClassAssignmentsScreen(
                            sectionId: section['id'],
                            sectionName: section['name'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// SCREEN 2: LEGACY TASK VIEWER & MIGRATION TOOL
// ============================================================================
class LegacyClassAssignmentsScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;

  const LegacyClassAssignmentsScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<LegacyClassAssignmentsScreen> createState() =>
      _LegacyClassAssignmentsScreenState();
}

class _LegacyClassAssignmentsScreenState
    extends State<LegacyClassAssignmentsScreen> {
  final _repo = AssignmentRepository();
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _periods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final periodsList = await _repo.getAvailablePeriods(widget.sectionId);
    final assigns = await _repo.getAssignments(widget.sectionId);

    if (mounted) {
      setState(() {
        _periods = periodsList;
        _assignments = assigns;
        _isLoading = false;
      });
    }
  }

  // Modals for creating and deleting supplementary tasks
  Future<void> _showCreateModal() async {
    final titleCtrl = TextEditingController();
    final scoreCtrl = TextEditingController(text: '100');
    String selectedType = 'Homework';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'New Supplementary Task',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _Brand.charcoal,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _buildInputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Brand.charcoal,
                  ),
                  decoration: _buildInputDecoration(labelText: 'Category'),
                  items: ['Homework', 'Project', 'Activity']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _buildInputDecoration(
                    labelText: 'Max Score Points',
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Target Due Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMMM d, yyyy').format(selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _Brand.tealDark,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _Brand.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: _Brand.teal,
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setModalState(() => selectedDate = date);
                  },
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
                if (titleCtrl.text.isEmpty || scoreCtrl.text.isEmpty) return;

                await _repo.createAssignment(
                  sectionId: widget.sectionId,
                  title: titleCtrl.text,
                  type: selectedType,
                  dueDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                  maxScore: int.parse(scoreCtrl.text),
                  periodId:
                      '', // Blank period marks it as supplementary/unmapped
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
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

  Future<void> _confirmDeleteTask(String assignmentId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Assignment?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This will permanently erase all student submissions and score tracking associated with it.',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _Brand.mutedText,
                fontWeight: FontWeight.bold,
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
              'Delete Permanently',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deleteAssignment(assignmentId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplementary task deleted.'),
            backgroundColor: _Brand.charcoal,
          ),
        );
      }
    }
  }

  void _openTrackingModal(String assignmentId, String title, dynamic maxScore) {
    // Safely cast maxScore to an integer (defaults to 100 if legacy data is weird)
    final parsedScore = (maxScore as num?)?.toInt() ?? 100;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TrackingBottomSheet(
        assignmentId: assignmentId,
        sectionId: widget.sectionId,
        title: title,
        maxScore: parsedScore,
        repo: _repo,
      ),
    ).then((_) => _loadData());
  }

  Future<void> _showMigrateDialog(String assignmentId, String title) async {
    if (_periods.isEmpty) return;
    String selectedPeriodId = _periods.first['id'] as String;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Migrate Assignment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign "$title" to an active academic period.',
                style: const TextStyle(color: _Brand.mutedText),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPeriodId,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Target Period',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _periods.map((p) {
                  return DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['name'] as String),
                  );
                }).toList(),
                onChanged: (v) => setModalState(() => selectedPeriodId = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _Brand.mutedText),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Brand.tealDark),
              onPressed: () async {
                await _repo.assignPeriodToTask(assignmentId, selectedPeriodId);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text(
                'Migrate',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final legacyTasks = _assignments.where((a) {
      final pid = a['period_id'];
      return pid == null || pid.toString().trim().isEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: _buildBrandedAppBar(
        context: context,
        title: 'Unmapped Tasks',
        subtitle: widget.sectionName,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : legacyTasks.isEmpty
          ? const Center(
              child: Text(
                'No supplementary assignments found for this class.',
                style: TextStyle(
                  color: _Brand.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: legacyTasks.length,
              itemBuilder: (context, index) {
                final a = legacyTasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200, width: 1.2),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _Brand.graySurf,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: _Brand.amberWarning,
                      ),
                    ),
                    title: Text(
                      a['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _Brand.charcoal,
                      ),
                    ),
                    subtitle: Text(
                      '${a['type']} • Max: ${a['max_score']}\nUnmapped Period',
                      style: const TextStyle(
                        color: _Brand.mutedText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.drive_file_move_outline,
                            color: _Brand.blueAccent,
                          ),
                          tooltip: 'Migrate to active period',
                          onPressed: () =>
                              _showMigrateDialog(a['id'], a['title']),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _Brand.teal),
                            foregroundColor: _Brand.tealDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () => _openTrackingModal(
                            a['id'],
                            a['title'],
                            a['max_score'],
                          ),
                          child: const Text(
                            'Track',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: _Brand.redText,
                            size: 20,
                          ),
                          tooltip: 'Delete Assignment',
                          onPressed: () =>
                              _confirmDeleteTask(a['id'], a['title']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      // Added FAB for new supplementary tasks
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Supp Task',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
