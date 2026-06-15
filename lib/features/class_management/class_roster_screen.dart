import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/section_model.dart';
import 'repositories/enrollment_repository.dart';
import 'enroll_students_screen.dart';
import 'class_attendance_screen.dart';

class ClassRosterScreen extends StatefulWidget {
  final Section section;

  const ClassRosterScreen({super.key, required this.section});

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen> {
  final _enrollRepo = EnrollmentRepository();
  List _students = [];
  bool _isLoading = true;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    final students = await _enrollRepo.getStudentsInSection(widget.section.id);
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
    }
  }

  Future<bool> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) return true;
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to unenroll this student',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> _confirmAndUnenroll(dynamic student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unenroll Student'),
        content: Text(
          'Remove "${student.fullName}" from ${widget.section.name}?\n\n'
          'Their records will be kept but they will no longer appear in this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Unenroll',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authenticated = await _authenticate();
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Student was not unenrolled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ Call the repository directly — no nested function
    await _enrollRepo.unenrollStudent(widget.section.id, student.id as int);

    if (mounted) {
      await _loadRoster();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${student.fullName} unenrolled from ${widget.section.name}.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.section.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Grade ${widget.section.gradeLevel} Roster',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.fact_check_rounded, color: Colors.teal),
              label: const Text(
                'Take Attendance',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ClassAttendanceScreen(section: widget.section),
                  ),
                ).then((_) => _loadRoster());
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.male_rounded), text: 'Boys'),
              Tab(icon: Icon(Icons.female_rounded), text: 'Girls'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildTabContent(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnrollStudentsScreen(
                  sectionId: widget.section.id,
                  sectionName: widget.section.name,
                ),
              ),
            ).then((value) {
              if (value == true) _loadRoster();
            });
          },
          label: const Text('Add Students'),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final boys = _students.where((s) {
      final g = (s.gender ?? '').toString().toLowerCase();
      return g == 'male' || g == 'm';
    }).toList();

    final girls = _students.where((s) {
      final g = (s.gender ?? '').toString().toLowerCase();
      return g == 'female' || g == 'f';
    }).toList();

    return TabBarView(
      children: [
        _buildRosterList(boys, 'No boys enrolled in this section.'),
        _buildRosterList(girls, 'No girls enrolled in this section.'),
      ],
    );
  }

  Widget _buildRosterList(List students, String emptyMessage) {
    if (students.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: students.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final student = students[index];

        return Dismissible(
          key: ValueKey(student.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.orange.shade800,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_off, color: Colors.white),
                SizedBox(height: 4),
                Text(
                  'Unenroll',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            await _confirmAndUnenroll(student);
            return false;
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade50,
              foregroundColor: Colors.teal.shade800,
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              student.fullName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}
