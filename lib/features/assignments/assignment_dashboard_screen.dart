import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'repository/assignment_repository.dart';

// ─── Unified Brand Palette ───────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
  static const bgSurface = Color(0xFFF9FAFB);
  static const amberWarning = Color(0xFFD97706);
  static const amberSurf = Color(0xFFFEF3C7);
  static const redText = Color(0xFFDC2626);
  static const redSurf = Color(0xFFFEE2E2);
  static const blueAccent = Color(0xFF2563EB);
  static const blueSurf = Color(0xFFDBEAFE);
}

// ─── Standardized Input Decoration Helper ────────────────────────────────────
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

// ============================================================================
// SCREEN 1: CLASS SELECTION HUB (CARDS VIEW)
// ============================================================================
class AssignmentHubScreen extends StatefulWidget {
  const AssignmentHubScreen({super.key});

  @override
  State<AssignmentHubScreen> createState() => _AssignmentHubScreenState();
}

class _AssignmentHubScreenState extends State<AssignmentHubScreen> {
  final _repo = AssignmentRepository();
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _viewingArchived = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);

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
      appBar: AppBar(
        title: Text(
          _viewingArchived ? 'Archived Classes' : 'Assignment Management',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _Brand.charcoal,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _viewingArchived
                ? 'View Active Classes'
                : 'View Archived Classes',
            icon: Icon(
              _viewingArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_rounded,
              color: _Brand.tealMid,
            ),
            onPressed: () {
              setState(() {
                _viewingArchived = !_viewingArchived;
              });
              _loadClasses();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _viewingArchived
                        ? Icons.inventory_2_outlined
                        : Icons.class_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _viewingArchived
                        ? 'No archived classes found.'
                        : 'No active classes found.',
                    style: const TextStyle(
                      color: _Brand.mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                if (isTablet) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 3.2,
                        ),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) =>
                        _buildClassCard(_classes[index]),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                    child: _buildClassCard(_classes[index]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> section) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassAssignmentsScreen(
                sectionId: section['id'],
                sectionName: section['name'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _viewingArchived
                          ? Colors.grey.shade100
                          : _Brand.tealSurf,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.class_rounded,
                      color: _viewingArchived
                          ? _Brand.mutedText
                          : _Brand.tealMid,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          section['name'],
                          style: const TextStyle(
                            color: _Brand.charcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _viewingArchived
                              ? 'Read-Only Archive'
                              : 'Manage Tasks & Performance',
                          style: const TextStyle(
                            color: _Brand.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
              Positioned(
                top: -6,
                right: -6,
                child: PopupMenuButton<String>(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 2: ASSIGNMENT LIST & TRACKER FOR SPECIFIC CLASS
// ============================================================================
class ClassAssignmentsScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;

  const ClassAssignmentsScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<ClassAssignmentsScreen> createState() => _ClassAssignmentsScreenState();
}

class _ClassAssignmentsScreenState extends State<ClassAssignmentsScreen> {
  final _repo = AssignmentRepository();
  List<Map<String, dynamic>> _assignments = [];
  List<int> _quarters = [1];
  int _selectedQuarter = 1;
  Map<String, dynamic>? _classSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final quartersList = await _repo.getAvailableQuarters(widget.sectionId);
    final summary = await _repo.getClassPerformanceSummary(widget.sectionId);
    final assigns = await _repo.getAssignments(widget.sectionId);

    if (mounted) {
      setState(() {
        _quarters = quartersList.isEmpty ? [1] : quartersList;
        if (!_quarters.contains(_selectedQuarter) && _quarters.isNotEmpty) {
          _selectedQuarter = _quarters.last;
        }
        _classSummary = summary;
        _assignments = assigns;
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateModal() async {
    final titleCtrl = TextEditingController();
    final scoreCtrl = TextEditingController(text: '100');
    String selectedType = 'Homework';
    int selectedQuarter = _selectedQuarter;
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
            'New Assignment Task',
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
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _Brand.charcoal,
                        ),
                        decoration: _buildInputDecoration(
                          labelText: 'Category',
                        ),
                        items: ['Homework', 'Project', 'Activity']
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        value: selectedQuarter,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _Brand.charcoal,
                        ),
                        decoration: _buildInputDecoration(labelText: 'Quarter'),
                        items: List.generate(8, (i) => i + 1)
                            .map(
                              (q) => DropdownMenuItem(
                                value: q,
                                child: Text('Q$q'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedQuarter = v!),
                      ),
                    ),
                  ],
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
                      color: _Brand.tealMid,
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
                  quarterNumber: selectedQuarter,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadDashboardData();
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
          'Are you sure you want to delete "$title"? This will also permanently erase all student submissions and score tracking associated with it.',
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
      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment and all linked submissions deleted.'),
            backgroundColor: _Brand.charcoal,
          ),
        );
      }
    }
  }

  void _openTrackingModal(String assignmentId, String title, int maxScore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TrackingBottomSheet(
        assignmentId: assignmentId,
        title: title,
        maxScore: maxScore,
        repo: _repo,
      ),
    ).then((_) => _loadDashboardData());
  }

  void _openStudentAveragesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StudentAveragesSheet(
        sectionId: widget.sectionId,
        quarterNumber: _selectedQuarter,
        repo: _repo,
      ),
    );
  }

  Map<String, Color> _getTypeColors(String type) {
    if (type == 'Homework')
      return {'bg': _Brand.blueSurf, 'text': _Brand.blueAccent};
    if (type == 'Project')
      return {'bg': const Color(0xFFF3E8FF), 'text': const Color(0xFF7C3AED)};
    return {'bg': _Brand.amberSurf, 'text': _Brand.amberWarning};
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssignments = _assignments
        .where((a) => a['quarter_number'] == _selectedQuarter)
        .toList();

    double currentQuarterAvg = 0.0;
    if (_classSummary != null) {
      final qStats = (_classSummary!['quarters'] as List).firstWhere(
        (q) => q['quarter_number'] == _selectedQuarter,
        orElse: () => {'class_quarter_average': 0.0},
      );
      currentQuarterAvg = (qStats['class_quarter_average'] as num).toDouble();
    }

    final overallCumulative = _classSummary?['overall_cumulative'] ?? 0.0;

    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: AppBar(
        title: Text(
          widget.sectionName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _Brand.charcoal,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Executive Executive Dashboard Banner
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _Brand.tealDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricStat(
                        'Quarter $_selectedQuarter Average',
                        '$currentQuarterAvg%',
                      ),
                      Container(width: 1, height: 36, color: Colors.white24),
                      _buildMetricStat(
                        'Cumulative Class Average',
                        '$overallCumulative%',
                      ),
                    ],
                  ),
                ),

                // Context Filter and Configuration Setup Row
                Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _quarters.map((q) {
                              final isSelected = _selectedQuarter == q;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text('Quarter $q'),
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
                                    if (selected)
                                      setState(() => _selectedQuarter = q);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'View Student Averages Matrix',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.bar_chart_rounded,
                          color: _Brand.tealMid,
                          size: 20,
                        ),
                        onPressed: _openStudentAveragesModal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Core Tasks Engine Pipeline
                Expanded(
                  child: filteredAssignments.isEmpty
                      ? Center(
                          child: Text(
                            'No active performance tasks assigned to Quarter $_selectedQuarter.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _Brand.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredAssignments.length,
                          itemBuilder: (context, index) {
                            final a = filteredAssignments[index];
                            final colors = _getTypeColors(a['type']);
                            return Container(
                              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.shade100,
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors['bg'],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.assignment_outlined,
                                    color: colors['text'],
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  a['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _Brand.charcoal,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${a['type']}  •  Due: ${a['due_date']}\nMax Target: ${a['max_score']} pts',
                                    style: const TextStyle(
                                      color: _Brand.mutedText,
                                      fontSize: 12,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: _Brand.teal,
                                        ),
                                        foregroundColor: _Brand.tealDark,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
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
                                      onPressed: () => _confirmDeleteTask(
                                        a['id'],
                                        a['title'],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Task Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMetricStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MODAL MATRIX SHEET: STUDENT AVERAGES
// ============================================================================
class StudentAveragesSheet extends StatefulWidget {
  final String sectionId;
  final int quarterNumber;
  final AssignmentRepository repo;

  const StudentAveragesSheet({
    super.key,
    required this.sectionId,
    required this.quarterNumber,
    required this.repo,
  });

  @override
  State<StudentAveragesSheet> createState() => _StudentAveragesSheetState();
}

class _StudentAveragesSheetState extends State<StudentAveragesSheet> {
  List<Map<String, dynamic>> _studentStats = [];
  bool _isLoading = true;
  int _sortColumnIndex = 0;
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await widget.repo.getStudentAveragesPerQuarter(
      sectionId: widget.sectionId,
      quarterNumber: widget.quarterNumber,
    );
    if (mounted) {
      setState(() {
        _studentStats = List<Map<String, dynamic>>.from(data);
        _sortData(_sortColumnIndex, _isSortAscending);
        _isLoading = false;
      });
    }
  }

  void _sortData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isSortAscending = ascending;

      _studentStats.sort((a, b) {
        if (columnIndex == 0) {
          return ascending
              ? a['full_name'].compareTo(b['full_name'])
              : b['full_name'].compareTo(a['full_name']);
        } else if (columnIndex == 1) {
          return ascending
              ? a['quarter_average'].compareTo(b['quarter_average'])
              : b['quarter_average'].compareTo(a['quarter_average']);
        } else if (columnIndex == 2) {
          return ascending
              ? a['overall_average'].compareTo(b['overall_average'])
              : b['overall_average'].compareTo(a['overall_average']);
        }
        return 0;
      });
    });
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return _Brand.tealDark;
    if (grade >= 75) return _Brand.amberWarning;
    return _Brand.redText;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quarter ${widget.quarterNumber} Performance Ledger',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _Brand.charcoal,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _Brand.mutedText,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _Brand.teal),
                  )
                : _studentStats.isEmpty
                ? const Center(
                    child: Text(
                      'No analytical data map populated.',
                      style: TextStyle(color: _Brand.mutedText),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.grey.shade100),
                        child: DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _isSortAscending,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _Brand.tealDark,
                            fontSize: 13,
                          ),
                          columns: [
                            DataColumn(
                              label: const Text('Student Full Name'),
                              onSort: (index, asc) => _sortData(index, asc),
                            ),
                            DataColumn(
                              label: Text('Q${widget.quarterNumber} Avg'),
                              numeric: true,
                              onSort: (index, asc) => _sortData(index, asc),
                            ),
                            DataColumn(
                              label: const Text('Cumulative Overall'),
                              numeric: true,
                              onSort: (index, asc) => _sortData(index, asc),
                            ),
                          ],
                          rows: _studentStats.map((stat) {
                            final qAvg = (stat['quarter_average'] as num)
                                .toDouble();
                            final oAvg = (stat['overall_average'] as num)
                                .toDouble();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    stat['full_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _Brand.charcoal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$qAvg%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getGradeColor(qAvg),
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${stat['quarter_earned']}/${stat['quarter_possible']} pts',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: _Brand.mutedText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '$oAvg%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getGradeColor(oAvg),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM SHEET: STATUS TRACKER FLOW MATRIX
// ============================================================================
class TrackingBottomSheet extends StatefulWidget {
  final String assignmentId;
  final String title;
  final int maxScore;
  final AssignmentRepository repo;

  const TrackingBottomSheet({
    super.key,
    required this.assignmentId,
    required this.title,
    required this.maxScore,
    required this.repo,
  });

  @override
  State<TrackingBottomSheet> createState() => _TrackingBottomSheetState();
}

class _TrackingBottomSheetState extends State<TrackingBottomSheet> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final data = await widget.repo.getSubmissionTracking(widget.assignmentId);
    if (mounted) {
      setState(() {
        _submissions = data;
        _isLoading = false;
      });
    }
  }

  Map<String, Color> _getStatusTokens(String status) {
    switch (status) {
      case 'Submitted':
        return {'bg': _Brand.tealSurf, 'text': _Brand.tealDark};
      case 'Late':
        return {'bg': _Brand.amberSurf, 'text': _Brand.amberWarning};
      case 'Missing':
        return {'bg': _Brand.redSurf, 'text': _Brand.redText};
      default:
        return {'bg': _Brand.bgSurface, 'text': _Brand.mutedText};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tracking: ${widget.title}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _Brand.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _Brand.tealSurf,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Max target: ${widget.maxScore} pts',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _Brand.tealDark,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF3F4F6), thickness: 1.5),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _Brand.teal),
                  )
                : _submissions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off_rounded,
                          size: 54,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No students to track!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _Brand.charcoal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'There were no students enrolled in this class context when the core assignment matrix was dispatched.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _Brand.mutedText,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _submissions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFFF9FAFB), thickness: 1),
                    itemBuilder: (context, index) {
                      final sub = _submissions[index];
                      final tokens = _getStatusTokens(sub['status']);
                      final scoreCtrl = TextEditingController(
                        text: sub['score'] != null
                            ? sub['score'].toString()
                            : '',
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub['full_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _Brand.charcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens['bg'],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sub['status'],
                                      style: TextStyle(
                                        color: tokens['text'],
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 65,
                                  height: 38,
                                  child: TextField(
                                    controller: scoreCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _Brand.charcoal,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '--',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                      filled: true,
                                      fillColor: _Brand.bgSurface,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: _Brand.teal,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (val) async {
                                      final newScore = double.tryParse(val);
                                      if (newScore != null &&
                                          newScore <= widget.maxScore) {
                                        await widget.repo
                                            .updateSubmissionStatus(
                                              assignmentId: widget.assignmentId,
                                              studentId: sub['student_id']
                                                  .toString(),
                                              status: 'Submitted',
                                              score: newScore,
                                            );
                                        _loadSubmissions();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: sub['status'],
                                    underline: const SizedBox(),
                                    dropdownColor: Colors.white,
                                    icon: const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 20,
                                      color: _Brand.mutedText,
                                    ),
                                    items:
                                        [
                                          'Pending',
                                          'Submitted',
                                          'Late',
                                          'Missing',
                                        ].map((s) {
                                          return DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: _Brand.charcoal,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (newStatus) async {
                                      if (newStatus != null) {
                                        final currentScore = double.tryParse(
                                          scoreCtrl.text,
                                        );
                                        await widget.repo
                                            .updateSubmissionStatus(
                                              assignmentId: widget.assignmentId,
                                              studentId: sub['student_id']
                                                  .toString(),
                                              status: newStatus,
                                              score: currentScore,
                                            );
                                        _loadSubmissions();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
