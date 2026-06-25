import 'package:flutter/material.dart';
import '../student_sis/models/student_model.dart';
import 'repositories/enrollment_repository.dart';

// ─── Brand palette (shared across TeachOS screens) ────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealLight = Color(0xFF5DCAA5);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);

  static const blueSurf = Color(0xFFE6F1FB);
  static const blueText = Color(0xFF185FA5);
  static const blueDark = Color(0xFF0C447C);
  static const blueBorder = Color(0xFFB5D4F4);
  static const blueMid = Color(0xFF378ADD);

  static const pinkSurf = Color(0xFFFBEAF0);
  static const pinkText = Color(0xFF993556);
  static const pinkBorder = Color(0xFFF4C0D1);
  static const pinkMid = Color(0xFFD4537E);

  static const amberSurf = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF854F0B);
  static const amberBorder = Color(0xFFFAC775);

  static const redSurf = Color(0xFFFCEBEB);
  static const redText = Color(0xFFA32D2D);
  static const redBorder = Color(0xFFF09595);
}
// ─────────────────────────────────────────────────────────────────────────────

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

class _EnrollStudentsScreenState extends State<EnrollStudentsScreen>
    with RestorationMixin<EnrollStudentsScreen> {
  final RestorableString _enrollStudentsScreen = RestorableString('');
  final _repo = EnrollmentRepository();

  bool _isLoading = true;
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  final List<int> _selectedStudentIds = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  String? get restorationId => 'enroll_students_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_enrollStudentsScreen, 'enroll_students_screen');
  }

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

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'[\s,]+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: Colors.black38),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Brand.tealMid, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterStudents,
                    style: const TextStyle(fontSize: 13),
                    decoration: _buildInputDecoration(
                      label: 'Search by name or ID...',
                      icon: Icons.search_rounded,
                    ),
                  ),
                ),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: Colors.grey.shade100,
                ),

                // Student List
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? Center(
                          child: Text(
                            'No matching students found.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final int studentId = student.id!;
                            final isChecked = _selectedStudentIds.contains(
                              studentId,
                            );
                            final initials = _getInitials(student.fullName);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedStudentIds.remove(studentId);
                                  } else {
                                    _selectedStudentIds.add(studentId);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? _Brand.tealSurf.withOpacity(0.3)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade100,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Circular Avatar
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isChecked
                                            ? _Brand.tealSurf
                                            : Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isChecked
                                              ? _Brand.tealBorder
                                              : Colors.transparent,
                                          width: 0.8,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isChecked
                                              ? _Brand.tealDark
                                              : Colors.black45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Student Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: $studentId',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Custom Check Indicator
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isChecked
                                            ? _Brand.tealMid
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isChecked
                                              ? _Brand.tealMid
                                              : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isChecked
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom == 0
              ? 16
              : MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.8),
          ),
        ),
        child: ElevatedButton(
          onPressed: _selectedStudentIds.isEmpty ? null : _saveEnrollments,
          style: ElevatedButton.styleFrom(
            backgroundColor: _Brand.tealMid,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade100,
            disabledForegroundColor: Colors.black26,
            elevation: 0,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Enroll Selected (${_selectedStudentIds.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 17,
            color: Colors.black54,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
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
          const Text(
            'Add Students',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            'to ${widget.sectionName}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
