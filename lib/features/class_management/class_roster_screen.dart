import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/section_model.dart';
import 'repositories/enrollment_repository.dart';
import 'enroll_students_screen.dart';
import 'class_attendance_screen.dart';

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

class ClassRosterScreen extends StatefulWidget {
  final Section section;
  const ClassRosterScreen({super.key, required this.section});

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen>
    with SingleTickerProviderStateMixin, RestorationMixin<ClassRosterScreen> {
  final RestorableString _classRosterScreen = RestorableString('');
  final _enrollRepo = EnrollmentRepository();
  final _localAuth = LocalAuthentication();

  List _students = [];
  bool _isLoading = true;

  late final TabController _tabController;

  @override
  String? get restorationId => 'class_roster_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_classRosterScreen, 'class_roster_screen');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoster();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadRoster() async {
    final students = await _enrollRepo.getStudentsInSection(widget.section.id);
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
    }
  }

  List get _boys => _students.where((s) {
    final g = (s.gender ?? '').toString().toLowerCase();
    return g == 'male' || g == 'm';
  }).toList();

  List get _girls => _students.where((s) {
    final g = (s.gender ?? '').toString().toLowerCase();
    return g == 'female' || g == 'f';
  }).toList();

  // ── Auth & unenroll ────────────────────────────────────────────────────────

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
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmAndUnenroll(dynamic student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unenroll student',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          'Remove "${student.fullName}" from ${widget.section.name}?\n\n'
          'Their records will be kept but they won\'t appear in this class.',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authenticated = await _authenticate();
    if (!authenticated) {
      if (mounted)
        _showSnackBar(
          'Authentication failed. Student was not unenrolled.',
          isWarning: true,
        );
      return;
    }

    await _enrollRepo.unenrollStudent(widget.section.id, student.id as int);
    if (mounted) {
      await _loadRoster();
      _showSnackBar(
        '${student.fullName} unenrolled from ${widget.section.name}.',
      );
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
                      _buildRosterList(_boys, isMale: true),
                      _buildRosterList(_girls, isMale: false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.section.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            'Grade ${widget.section.gradeLevel} roster',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClassAttendanceScreen(section: widget.section),
                ),
              ).then((_) => _loadRoster());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _Brand.tealBorder, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.fact_check_rounded,
                    size: 15,
                    color: _Brand.tealMid,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Take attendance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _Brand.tealDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: Colors.grey.shade200),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.transparent, // handled by custom tab
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

  // ── Roster List ────────────────────────────────────────────────────────────

  Widget _buildRosterList(List students, {required bool isMale}) {
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
                isMale ? 'No boys enrolled' : 'No girls enrolled',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "Add students" below to enroll students in this section.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black38,
                  height: 1.5,
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
        return _buildStudentRow(student, isMale: isMale);
      },
    );
  }

  Widget _buildStudentRow(dynamic student, {required bool isMale}) {
    final initials = _getInitials(student.fullName as String);

    return Dismissible(
      key: ValueKey(student.id),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBackground(),
      confirmDismiss: (_) async {
        await _confirmAndUnenroll(student);
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
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isMale ? _Brand.blueSurf : _Brand.pinkSurf,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMale ? _Brand.blueDark : _Brand.pinkText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                student.fullName as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Swipe hint
            Row(
              children: const [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 13,
                  color: Colors.black26,
                ),
                Text(
                  'Unenroll',
                  style: TextStyle(fontSize: 10, color: Colors.black26),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Swipe Background ───────────────────────────────────────────────────────

  Widget _buildSwipeBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: _Brand.amberSurf,
        border: Border.all(color: _Brand.amberBorder, width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.link_off_rounded, color: _Brand.amberText, size: 20),
          SizedBox(height: 3),
          Text(
            'Unenroll',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _Brand.amberText,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnrollStudentsScreen(
              sectionId: widget.section.id,
              sectionName: widget.section.name,
            ),
          ),
        ).then((v) {
          if (v == true) _loadRoster();
        });
      },
      backgroundColor: _Brand.tealMid,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text(
        'Add students',
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'[\s,]+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    // Handle "Lastname, Firstname" or "First Last"
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
