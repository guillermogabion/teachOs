import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'repository/assignment_repository.dart';

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

  // Controls whether we are viewing Active or Archived classes
  bool _viewingArchived = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);

    // Fetch based on current view mode
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          _viewingArchived ? 'Archived Classes' : 'Assignment Management',
        ),
        backgroundColor: _viewingArchived
            ? Colors.blueGrey.shade700
            : Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Toggle Button to switch views
          IconButton(
            tooltip: _viewingArchived
                ? 'View Active Classes'
                : 'View Archived Classes',
            icon: Icon(
              _viewingArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_rounded,
            ),
            onPressed: () {
              setState(() {
                _viewingArchived = !_viewingArchived;
              });
              _loadClasses();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _viewingArchived
                        ? 'No archived classes.'
                        : 'No active classes found.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                if (isTablet) {
                  // Original grid for tablets
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 3.1,
                        ),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) =>
                        _buildClassCard(_classes[index]),
                  );
                }

                // Mobile: single column list
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                    child: _buildClassCard(_classes[index]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> section) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _viewingArchived
                  ? [Colors.blueGrey.shade400, Colors.blueGrey.shade600]
                  : [Colors.indigo.shade500, Colors.indigo.shade800],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.class_rounded,
                    color: Colors.white70,
                    size: 36,
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
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _viewingArchived
                              ? 'Read-Only'
                              : 'Manage Tasks & Performance',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32), // space for the 3-dot menu
                ],
              ),

              // 3-Dot Options Menu
              Positioned(
                top: -8,
                right: -8,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
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
                        child: Text('Archive Class'),
                      ),
                    if (_viewingArchived)
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore to Active'),
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
  List<int> _quarters = [1]; // Defaults to Q1 if empty
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

    // Fetch all dynamic data in parallel
    final quartersList = await _repo.getAvailableQuarters(widget.sectionId);
    final summary = await _repo.getClassPerformanceSummary(widget.sectionId);
    final assigns = await _repo.getAssignments(widget.sectionId);

    if (mounted) {
      setState(() {
        _quarters = quartersList.isEmpty ? [1] : quartersList;
        // Ensure the selected quarter is valid, otherwise default to the latest
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
    int selectedQuarter =
        _selectedQuarter; // Default to the currently viewed quarter
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('New Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
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
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        value: selectedQuarter,
                        decoration: const InputDecoration(
                          labelText: 'Quarter',
                          border: OutlineInputBorder(),
                        ),
                        // Allow them to pick existing quarters or create a new one (up to Q8 for flexibility)
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
                const SizedBox(height: 12),
                TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Score',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due Date'),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy').format(selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
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
                  _loadDashboardData(); // Refresh everything
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
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
    ).then(
      (_) => _loadDashboardData(),
    ); // Reload averages when bottom sheet closes
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

  Color _getTypeColor(String type) {
    if (type == 'Homework') return Colors.blue;
    if (type == 'Project') return Colors.purple;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    // Filter assignments for the currently selected quarter tab
    final filteredAssignments = _assignments
        .where((a) => a['quarter_number'] == _selectedQuarter)
        .toList();

    // Extract quarter average safely
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.sectionName),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CLASS SUMMARY HEADER
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.indigo.shade700,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricStat(
                        'Q$_selectedQuarter Avg',
                        '$currentQuarterAvg%',
                      ),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _buildMetricStat('Cumulative Avg', '$overallCumulative%'),
                    ],
                  ),
                ),

                // 2. DYNAMIC QUARTER TABS
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _quarters
                                .map(
                                  (q) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text('Quarter $q'),
                                      selected: _selectedQuarter == q,
                                      selectedColor: Colors.indigo.shade100,
                                      labelStyle: TextStyle(
                                        color: _selectedQuarter == q
                                            ? Colors.indigo.shade900
                                            : Colors.black87,
                                        fontWeight: _selectedQuarter == q
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      onSelected: (selected) {
                                        if (selected)
                                          setState(() => _selectedQuarter = q);
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      // Button to view individual student averages for this quarter
                      IconButton(
                        tooltip: 'View Student Averages',
                        icon: const Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.indigo,
                        ),
                        onPressed: _openStudentAveragesModal,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // 3. ASSIGNMENTS LIST FOR SELECTED QUARTER
                Expanded(
                  child: filteredAssignments.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks in Quarter $_selectedQuarter yet.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAssignments.length,
                          itemBuilder: (context, index) {
                            final a = filteredAssignments[index];
                            return Card(
                              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: _getTypeColor(
                                    a['type'],
                                  ).withOpacity(0.2),
                                  child: Icon(
                                    Icons.assignment,
                                    color: _getTypeColor(a['type']),
                                  ),
                                ),
                                title: Text(
                                  a['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${a['type']} • Due: ${a['due_date']}',
                                    ),
                                    Text(
                                      'Max Score: ${a['max_score']} pts',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: FilledButton.tonal(
                                  onPressed: () => _openTrackingModal(
                                    a['id'],
                                    a['title'],
                                    a['max_score'],
                                  ),
                                  child: const Text('Track'),
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
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  Widget _buildMetricStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

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

  // Sorting States
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
        _sortData(
          _sortColumnIndex,
          _isSortAscending,
        ); // Apply default sort (Name ASC)
        _isLoading = false;
      });
    }
  }

  // Local sorting logic for instant UI feedback without hitting the database
  void _sortData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isSortAscending = ascending;

      _studentStats.sort((a, b) {
        if (columnIndex == 0) {
          // Sort by Name
          return ascending
              ? a['full_name'].compareTo(b['full_name'])
              : b['full_name'].compareTo(a['full_name']);
        } else if (columnIndex == 1) {
          // Sort by Quarter Average
          return ascending
              ? a['quarter_average'].compareTo(b['quarter_average'])
              : b['quarter_average'].compareTo(a['quarter_average']);
        } else if (columnIndex == 2) {
          // Sort by Overall Average
          return ascending
              ? a['overall_average'].compareTo(b['overall_average'])
              : b['overall_average'].compareTo(a['overall_average']);
        }
        return 0;
      });
    });
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return Colors.green.shade700;
    if (grade >= 75) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quarter ${widget.quarterNumber} Performance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _studentStats.isEmpty
                ? const Center(child: Text('No student data available.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _isSortAscending,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        columns: [
                          DataColumn(
                            label: const Text('Student Name'),
                            onSort: (index, ascending) =>
                                _sortData(index, ascending),
                          ),
                          DataColumn(
                            label: Text('Q${widget.quarterNumber} Average'),
                            numeric: true,
                            onSort: (index, ascending) =>
                                _sortData(index, ascending),
                          ),
                          DataColumn(
                            label: const Text('Overall Average'),
                            numeric: true,
                            tooltip: 'Cumulative average across all quarters',
                            onSort: (index, ascending) =>
                                _sortData(index, ascending),
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
                                      ),
                                    ),
                                    Text(
                                      '${stat['quarter_earned']} / ${stat['quarter_possible']} pts',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
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
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM SHEET: THE STATUS TRACKER (Submitted, Late, Missing)
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Missing':
        return Colors.red;
      default:
        return Colors.grey; // Pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tracking: ${widget.title}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Max: ${widget.maxScore} pts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          // LIST VIEW
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _submissions.isEmpty
                // THE FIX: Explicit warning if the class was empty when the task was created
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No students to track!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'There were no students enrolled in this class when you created this assignment. Please enroll students first, then create a new task.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _submissions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sub = _submissions[index];

                      // Track local text controller for the score input
                      final scoreCtrl = TextEditingController(
                        text: sub['score'] != null
                            ? sub['score'].toString()
                            : '',
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            // Left Side: Name and Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub['full_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        sub['status'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sub['status'],
                                      style: TextStyle(
                                        color: _getStatusColor(sub['status']),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right Side: High Speed Matrix (Score + Dropdown)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Quick Score Input
                                SizedBox(
                                  width: 65,
                                  child: TextField(
                                    controller: scoreCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '--',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onSubmitted: (val) async {
                                      final newScore = double.tryParse(val);
                                      if (newScore != null &&
                                          newScore <= widget.maxScore) {
                                        // Automatically update status to Submitted if they enter a score
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

                                // Status Toggle Dropdown
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: sub['status'],
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                    ),
                                    items:
                                        [
                                              'Pending',
                                              'Submitted',
                                              'Late',
                                              'Missing',
                                            ]
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (newStatus) async {
                                      if (newStatus != null) {
                                        // Retain the current score if they are just changing the status to Late/Missing
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
