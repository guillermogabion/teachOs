import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../attendance/repository/attendance_repository.dart';
import 'models/section_model.dart';

class ClassAttendanceScreen extends StatefulWidget {
  final Section section;

  const ClassAttendanceScreen({super.key, required this.section});

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.section.name} Roll Call',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Grade ${widget.section.gradeLevel}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            if (_hasExistingData)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadClassRoster();
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
            ),

            // Data Status Notice Badge
            Container(
              width: double.infinity,
              color: _hasExistingData
                  ? Colors.amber.shade50
                  : Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Text(
                _hasExistingData
                    ? 'Viewing saved attendance roll. Modifying fields will run an overwrite update.'
                    : 'No logs found for this date. Displaying temporary default values.',
                style: TextStyle(
                  fontSize: 11,
                  color: _hasExistingData
                      ? Colors.amber.shade900
                      : Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Segregated Gender Tabs Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.teal,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: 'Male (${_maleStudentIds.length})'),
                  Tab(text: 'Female (${_femaleStudentIds.length})'),
                ],
              ),
            ),

            // Tab Views for Roster Lists
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildAttendanceList(_maleStudentIds),
                        _buildAttendanceList(_femaleStudentIds),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: _commitToDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _hasExistingData
                    ? 'Update Saved Attendance'
                    : 'Save Attendance Record',
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
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      itemCount: studentIds.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final studentId = studentIds[index];
        final currentStatus = _localAttendanceState[studentId] ?? 'PRESENT';

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        _studentNames[studentId] ?? 'Unknown Student',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
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
                      activeColor: Colors.teal,
                      onTap: () => setState(
                        () => _localAttendanceState[studentId] = 'PRESENT',
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusButton(
                      label: 'Absent',
                      isActive: currentStatus == 'ABSENT',
                      activeColor: Colors.red.shade600,
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
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
