import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/student_model.dart';
import 'repositories/student_repository.dart';
import 'add_student_screen.dart';

// ─── Brand palette (shared across TeachOS screens) ────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
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
}
// ─────────────────────────────────────────────────────────────────────────────

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen>
    with SingleTickerProviderStateMixin {
  final _studentRepo = StudentRepository();
  final _localAuth = LocalAuthentication();

  List<Student> _students = [];
  bool _isLoading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data Getters ───────────────────────────────────────────────────────────

  Future<void> _loadStudents() async {
    final students = await _studentRepo.getAllStudents();
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
    }
  }

  List<Student> get _boys => _students.where((s) {
    final g = (s.gender ?? '').toLowerCase();
    return g == 'male' || g == 'm';
  }).toList();

  List<Student> get _girls => _students.where((s) {
    final g = (s.gender ?? '').toLowerCase();
    return g == 'female' || g == 'f';
  }).toList();

  // ── Biometric Auth & Deletion ──────────────────────────────────────────────

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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${student.fullName}"? '
          'This action cannot be undone.',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black45),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.amberText,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authenticated = await _authenticate();
    if (!authenticated) {
      if (mounted) {
        _showSnackBar(
          'Authentication failed. Student was not deleted.',
          isWarning: true,
        );
      }
      return;
    }

    await _studentRepo.deleteStudent(student.id!);

    if (mounted) {
      setState(() {
        _students.removeWhere((s) => s.id == student.id);
      });
      _showSnackBar('${student.fullName} has been permanently deleted.');
    }
  }

  void _showSnackBar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isWarning ? _Brand.amberText : _Brand.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  // ── Build Stage ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                _buildStatsRow(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudentList(
                        _boys,
                        isMale: true,
                        emptyMessage: 'No male students found.',
                      ),
                      _buildStudentList(
                        _girls,
                        isMale: false,
                        emptyMessage: 'No female students found.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── AppBar & Custom Tabs ───────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Student Directory',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          letterSpacing: -0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: Colors.grey.shade200),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              tabs: [
                _buildTab(
                  icon: Icons.male_rounded,
                  label: 'Boys',
                  count: _boys.length,
                  activeColor: _Brand.blueText,
                  activeSurf: _Brand.blueSurf,
                  activeBorder: _Brand.blueBorder,
                  activeIndicator: _Brand.blueMid,
                  tabIndex: 0,
                ),
                _buildTab(
                  icon: Icons.female_rounded,
                  label: 'Girls',
                  count: _girls.length,
                  activeColor: _Brand.pinkText,
                  activeSurf: _Brand.pinkSurf,
                  activeBorder: _Brand.pinkBorder,
                  activeIndicator: _Brand.pinkMid,
                  tabIndex: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required int count,
    required Color activeColor,
    required Color activeSurf,
    required Color activeBorder,
    required Color activeIndicator,
    required int tabIndex,
  }) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final isActive = _tabController.index == tabIndex;
        return Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeIndicator : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : Colors.black38,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? activeColor : Colors.black38,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? activeSurf : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isActive ? activeBorder : Colors.grey.shade200,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isActive ? activeColor : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _statChip(
            Icons.people_rounded,
            'Total',
            _students.length,
            Colors.black45,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ),
          const SizedBox(width: 8),
          _statChip(
            Icons.male_rounded,
            'Boys',
            _boys.length,
            _Brand.blueText,
            _Brand.blueSurf,
            _Brand.blueBorder,
          ),
          const SizedBox(width: 8),
          _statChip(
            Icons.female_rounded,
            'Girls',
            _girls.length,
            _Brand.pinkText,
            _Brand.pinkSurf,
            _Brand.pinkBorder,
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    IconData icon,
    String label,
    int count,
    Color color,
    Color bg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Content Lists ─────────────────────────────────────────────────────

  Widget _buildStudentList(
    List<Student> students, {
    required bool isMale,
    required String emptyMessage,
  }) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isMale ? _Brand.blueSurf : _Brand.pinkSurf,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isMale ? Icons.male_rounded : Icons.female_rounded,
                  color: isMale ? _Brand.blueText : _Brand.pinkText,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];

        return Dismissible(
          key: ValueKey(student.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: _Brand.amberSurf,
              border: Border.all(color: _Brand.amberBorder, width: 0.8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.delete_outline_rounded,
                  color: _Brand.amberText,
                  size: 20,
                ),
                SizedBox(height: 3),
                Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _Brand.amberText,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            await _confirmAndDelete(student);
            return false;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Avatar Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isMale ? _Brand.blueSurf : _Brand.pinkSurf,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMale ? _Brand.blueDark : _Brand.pinkText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Core Roster Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Edit Button Trigger
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Colors.black38,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddStudentScreen(studentToEdit: student),
                      ),
                    ).then((value) {
                      if (value == true) _loadStudents();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── FAB Layout ─────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddStudentScreen()),
        ).then((value) {
          if (value == true) _loadStudents();
        });
      },
      backgroundColor: _Brand.tealMid,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
      label: const Text(
        'Add Student',
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }
}
