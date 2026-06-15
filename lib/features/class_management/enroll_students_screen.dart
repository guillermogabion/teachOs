import 'package:flutter/material.dart';
import '../student_sis/models/student_model.dart';
import 'repositories/enrollment_repository.dart';

// Unified Design System
class _Brand {
  static const Color teal = Colors.teal;
  static final Color tealSurf = Colors.teal.shade50;
  static final Color greySurf = Colors.grey.shade50;
  static final Color greyBorder = Colors.grey.shade200;
}

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
      debugPrint("============= ERROR: $e =============");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        return student.fullName.toLowerCase().contains(lowerQuery) ||
            student.id.toString().contains(lowerQuery);
      }).toList();
    });
  }

  void _saveEnrollments() async {
    if (_selectedStudentIds.isEmpty) return;

    await _repo.enrollStudents(widget.sectionId, _selectedStudentIds);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.black45),
      filled: true,
      fillColor: _Brand.greySurf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _Brand.greyBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add to ${widget.sectionName}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterStudents,
                    decoration: _buildInputDecoration(
                      label: 'Search by name or ID...',
                      icon: Icons.search_rounded,
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Student List
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? Center(
                          child: Text(
                            'No matching students found.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final int studentId = student.id!;
                            final isChecked = _selectedStudentIds.contains(
                              studentId,
                            );

                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: _Brand.teal,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
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
              backgroundColor: _Brand.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Enroll Selected Students (${_selectedStudentIds.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
