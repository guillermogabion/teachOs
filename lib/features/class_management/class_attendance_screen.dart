import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../attendance/repository/attendance_repository.dart';
import 'models/section_model.dart';

class _Brand {
  static const Color teal = Color(0xFF00897B);
  static const Color tealSurf = Color(0xFFB2DFDB);
  static const Color tealMid = Color(0xFF00796B);
  static const Color tealLight = Color(0xFF80CBC4);
  static const Color redText = Color(0xFFB00020);
  static const Color redSurf = Color(0xFFFFEBEE);
  static const Color redBorder = Color(0xFFEF9A9A);
  static const Color amberSurf = Color(0xFFFFF8E1);
  static const Color amberText = Color(0xFFFFA000);
  static const Color blueSurf = Color(0xFFE3F2FD);
  static const Color blueText = Color(0xFF1976D2);
}

class ClassAttendanceScreen extends StatefulWidget {
  final Section section;

  const ClassAttendanceScreen({super.key, required this.section});

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen>
    with RestorationMixin<ClassAttendanceScreen> {
  final RestorableString _classAttendanceScreen = RestorableString('');
  final _attendanceRepo = AttendanceRepository();
  DateTime _selectedDate = DateTime.now();

  // Local state memory map tracking: { student_id : status }
  final Map<int, String> _localAttendanceState = {};
  final Map<int, String> _studentNames = {};

  // Track student IDs segregated by gender
  final List<int> _maleStudentIds = [];
  final List<int> _femaleStudentIds = [];

  bool _isLoading = true;
  bool _hasExistingData = false;

  @override
  String? get restorationId => 'class_attendance_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_classAttendanceScreen, 'class_attendance_screen');
  }

  @override
  void initState() {
    super.initState();
    _loadClassRoster();
  }

  void _loadClassRoster() async {
    setState(() => _isLoading = true);
    _localAttendanceState.clear();
    _studentNames.clear();
    _maleStudentIds.clear();
    _femaleStudentIds.clear();

    final dateKey = _selectedDate.toIso8601String().split('T')[0];

    try {
      final dbData = await _attendanceRepo.getSectionAttendanceRoster(
        widget.section.id,
        dateKey,
      );

      bool historicalRecordsFound = false;
      for (var row in dbData) {
        // 🚨 DEBUG LOGGER: Check your terminal to see exactly what keys/values exist!
        debugPrint('🚨 DB ROW DATA: $row');

        final int studentId = row['student_id'] as int;
        final existingStatus = row['status'] as String?;

        // Extract gender securely, supporting strings, ints, or alternate keys
        dynamic rawGenderValue = row['gender'] ?? row['sex'];
        final String rawGender = (rawGenderValue?.toString() ?? '')
            .trim()
            .toUpperCase();

        _studentNames[studentId] =
            row['full_name'] as String? ?? 'Unknown Student';

        // Robust matching logic (Handles words, letters, and common binary integer formats)
        if (rawGender == 'FEMALE' ||
            rawGender == 'F' ||
            rawGender == '2' ||
            rawGender == '0') {
          _femaleStudentIds.add(studentId);
        } else if (rawGender == 'MALE' ||
            rawGender == 'M' ||
            rawGender == '1') {
          _maleStudentIds.add(studentId);
        } else {
          // Visual warning fallback if parsing failed entirely
          debugPrint(
            '⚠️ Warning: Gender unmapped for student $studentId. Value: "$rawGender"',
          );
          _maleStudentIds.add(studentId);
        }

        // State tracking for logs
        if (existingStatus != null) {
          historicalRecordsFound = true;
          _localAttendanceState[studentId] = existingStatus;
        } else {
          _localAttendanceState[studentId] = 'PRESENT';
        }
      }

      setState(() {
        _hasExistingData = historicalRecordsFound;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to load class roster: $e");
      setState(() => _isLoading = false);
    }
  }

  void _commitToDatabase() async {
    final dateKey = _selectedDate.toIso8601String().split('T')[0];

    List<Map<String, dynamic>> recordsToSave = [];
    _localAttendanceState.forEach((studentId, status) {
      recordsToSave.add({
        'id': 'ATT_${studentId}_SEC_${widget.section.id}_$dateKey',
        'student_id': studentId,
        'date': dateKey,
        'status': status,
      });
    });

    try {
      await _attendanceRepo.saveClassAttendance(
        sectionId: widget.section.id,
        date: dateKey,
        studentStatuses: recordsToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance records committed securely.'),
          ),
        );
        _loadClassRoster();
      }
    } catch (e) {
      debugPrint("Database write failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearDayLogs() async {
    final dateKey = _selectedDate.toIso8601String().split('T')[0];

    try {
      await _attendanceRepo.deleteSectionAttendance(widget.section.id, dateKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cleared all attendance markers for this date.'),
          ),
        );
        _loadClassRoster();
      }
    } catch (e) {
      debugPrint("Failed to clear logs: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('MMMM d, yyyy').format(_selectedDate);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white, // Switched to white for a cleaner base
        appBar: AppBar(
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.section.name} Roll Call',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Grade ${widget.section.gradeLevel}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          actions: [
            if (_hasExistingData)
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: _Brand.redText,
                ), // Assuming _Brand.redText exists
                tooltip: 'Wipe Logs for This Day',
                onPressed: _clearDayLogs,
              ),
          ],
        ),
        body: Column(
          children: [
            // Dynamic Date Picker Bar Strip
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: _Brand.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: _Brand.teal,
                              onPrimary: Colors.white,
                              onSurface: Colors.black87,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadClassRoster();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: 14,
                            color: _Brand.teal,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _Brand.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Data Status Notice Badge
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: _hasExistingData ? _Brand.amberSurf : _Brand.blueSurf,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hasExistingData
                      ? Colors.amber.shade200
                      : Colors.blue.shade200,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasExistingData
                        ? Icons.info_outline_rounded
                        : Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: _hasExistingData
                        ? _Brand.amberText
                        : _Brand.blueText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasExistingData
                          ? 'Viewing saved attendance. Modifications will overwrite.'
                          : 'No logs found for this date. Displaying defaults.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasExistingData
                            ? _Brand.amberText
                            : _Brand.blueText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Segregated Gender Tabs Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
                ),
              ),
              child: TabBar(
                labelColor: _Brand.teal,
                unselectedLabelColor: Colors.black45,
                indicatorColor: _Brand.teal,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: 'Male (${_maleStudentIds.length})'),
                  Tab(text: 'Female (${_femaleStudentIds.length})'),
                ],
              ),
            ),

            // Tab Views for Roster Lists
            Expanded(
              child: Container(
                color: Colors
                    .grey
                    .shade50, // Slight off-white for the list background
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _Brand.teal),
                      )
                    : TabBarView(
                        children: [
                          _buildAttendanceList(_maleStudentIds),
                          _buildAttendanceList(_femaleStudentIds),
                        ],
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 0.8),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ElevatedButton(
                onPressed: _commitToDatabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Brand.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _hasExistingData
                      ? 'Update Saved Attendance'
                      : 'Save Attendance Record',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceList(List<int> studentIds) {
    if (studentIds.isEmpty) {
      return const Center(
        child: Text(
          'No records found for this category.',
          style: TextStyle(color: Colors.black45, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      itemCount: studentIds.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemBuilder: (context, index) {
        final studentId = studentIds[index];
        final currentStatus = _localAttendanceState[studentId] ?? 'PRESENT';

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Optional: A small avatar or initial block looks great here
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (_studentNames[studentId] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _studentNames[studentId] ?? 'Unknown Student',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildStatusButton(
                      label: 'Present',
                      isActive: currentStatus == 'PRESENT',
                      activeBgColor: _Brand.tealSurf,
                      activeTextColor: _Brand.tealMid,
                      activeBorderColor: _Brand.tealLight,
                      onTap: () => setState(
                        () => _localAttendanceState[studentId] = 'PRESENT',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusButton(
                      label: 'Absent',
                      isActive: currentStatus == 'ABSENT',
                      activeBgColor: _Brand
                          .redSurf, // Assuming these exist in your _Brand class
                      activeTextColor: _Brand.redText,
                      activeBorderColor: _Brand.redBorder,
                      onTap: () => setState(
                        () => _localAttendanceState[studentId] = 'ABSENT',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required bool isActive,
    required Color activeBgColor,
    required Color activeTextColor,
    required Color activeBorderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isActive ? activeBorderColor : Colors.grey.shade200,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? activeTextColor : Colors.black45,
          ),
        ),
      ),
    );
  }
}
