import 'package:flutter/material.dart';
import '../student_sis/models/student_model.dart';
import 'repositories/enrollment_repository.dart';

class EnrollStudentsScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;

  const EnrollStudentsScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<EnrollStudentsScreen> createState() => _EnrollStudentsScreenState();
}

class _EnrollStudentsScreenState extends State<EnrollStudentsScreen> {
  final _repo = EnrollmentRepository();

  bool _isLoading = true;
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];

  // UPDATE 1: Change to store integers instead of Strings
  final List<int> _selectedStudentIds = [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailableStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableStudents() async {
    try {
      final students = await _repo.getStudentsAvailableForSection(
        widget.sectionId,
      );
      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading students: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredStudents = _allStudents);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        // UPDATE 2: Convert the int ID to a string to check if it contains the search query
        return student.fullName.toLowerCase().contains(lowerQuery) ||
            student.id.toString().contains(lowerQuery);
      }).toList();
    });
  }

  void _saveEnrollments() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student.')),
      );
      return;
    }

    await _repo.enrollStudents(widget.sectionId, _selectedStudentIds);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.sectionName}'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allStudents.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'All directory students are already assigned to this class, or your directory is empty.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _filterStudents('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _filterStudents,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? Center(
                          child: Text(
                            'No students match your search.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];

                            // UPDATE 3: Ensure we enforce the ID as non-null since it came from DB
                            final int studentId = student.id!;
                            final isChecked = _selectedStudentIds.contains(
                              studentId,
                            );

                            return CheckboxListTile(
                              title: Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('ID: $studentId'),
                              value: isChecked,
                              activeColor: Colors.teal,
                              onChanged: (bool? value) {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  if (value == true) {
                                    _selectedStudentIds.add(studentId);
                                  } else {
                                    _selectedStudentIds.remove(studentId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedStudentIds.isEmpty ? null : _saveEnrollments,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Enroll Selected Students (${_selectedStudentIds.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
