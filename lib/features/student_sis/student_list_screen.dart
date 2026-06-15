import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/student_model.dart';
import 'repositories/student_repository.dart';
import 'add_student_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _studentRepo = StudentRepository();
  final _localAuth = LocalAuthentication();
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final students = await _studentRepo.getAllStudents();
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
    }
  }

  Future<bool> _authenticate() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to delete the student.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmAndDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Student',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${student.fullName}"? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // ✅ No refresh needed — list is untouched

    final authenticated = await _authenticate();
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Authentication failed. Student was not deleted.',
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    await _studentRepo.deleteStudent(student.id!);

    if (mounted) {
      setState(() {
        _students.removeWhere((s) => s.id == student.id); // ✅ instant removal
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName} has been deleted.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'Student Directory',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.teal.shade100,
            indicatorColor: Colors.amberAccent,
            indicatorWeight: 4.0,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.male, size: 22), text: 'Male Students'),
              Tab(icon: Icon(Icons.female, size: 22), text: 'Female Students'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.teal.shade700),
              )
            : _buildTabContent(),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text(
            'Add Student',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddStudentScreen()),
            ).then((value) {
              if (value == true) _loadStudents(); // ✅ reload after adding
            });
          },
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No students registered yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final maleStudents = _students.where((s) {
      final g = (s.gender ?? '').toLowerCase();
      return g == 'male' || g == 'm';
    }).toList();

    final femaleStudents = _students.where((s) {
      final g = (s.gender ?? '').toLowerCase();
      return g == 'female' || g == 'f';
    }).toList();

    return TabBarView(
      children: [
        _buildStudentList(maleStudents, 'No male students found.'),
        _buildStudentList(femaleStudents, 'No female students found.'),
      ],
    );
  }

  Widget _buildStudentList(List<Student> students, String emptyMessage) {
    if (students.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12.0),
          child: Dismissible(
            key: ValueKey(student.id),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24.0),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, color: Colors.white, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              await _confirmAndDelete(student);
              return false; // ✅ we manage the list manually
            },
            child: Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.shade50,
                  child: Text(
                    student.fullName.isNotEmpty
                        ? student.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                title: Text(
                  student.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: ${student.id}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      if (student.middleName != null &&
                          student.middleName!.isNotEmpty)
                        Text(
                          'Middle Name: ${student.middleName}',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 12,
                          ),
                        ),
                      if (student.birthdate != null &&
                          student.birthdate!.isNotEmpty)
                        Text(
                          'DOB: ${student.birthdate}',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: Colors.teal.shade700,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddStudentScreen(studentToEdit: student),
                        ),
                      ).then((value) {
                        if (value == true)
                          _loadStudents(); // ✅ reload after editing
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
