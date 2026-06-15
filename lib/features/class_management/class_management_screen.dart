import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';
import 'add_section_screen.dart';
import 'class_roster_screen.dart';
import 'archived_classes_screen.dart';

// ─── Brand palette (shared with DashboardScreen) ──────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealLight = Color(0xFF5DCAA5);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);

  static const blueSurf = Color(0xFFE6F1FB);
  static const blueText = Color(0xFF185FA5);
  static const blueBorder = Color(0xFFB5D4F4);

  static const pinkSurf = Color(0xFFFBEAF0);
  static const pinkText = Color(0xFF993556);
  static const pinkBorder = Color(0xFFF4C0D1);

  static const redSurf = Color(0xFFFCEBEB);
  static const redText = Color(0xFFA32D2D);
  static const redBorder = Color(0xFFF09595);
}
// ─────────────────────────────────────────────────────────────────────────────

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _sectionRepo = SectionRepository();
  final _localAuth = LocalAuthentication();

  List<Section> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final sections = await _sectionRepo.getActiveSections();
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
  }

  // ── Auth & delete ──────────────────────────────────────────────────────────

  Future<bool> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) return true;
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete this class',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmAndDelete(Section section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete class',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          'Permanently delete "${section.name}"?\n\n'
          'All enrollments linked to this class will also be removed.',
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
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.redText,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
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
          'Authentication failed. Class was not deleted.',
          isError: true,
        );
      }
      return;
    }

    await _sectionRepo.deleteSection(section.id);
    if (mounted) {
      setState(() => _sections.removeWhere((s) => s.id == section.id));
      _showSnackBar('"${section.name}" has been deleted.');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? _Brand.redText : _Brand.tealDark,
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
          : _sections.isEmpty
          ? _buildEmptyState()
          : _buildList(),
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
      title: const Text(
        'Current classes',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          fontSize: 17,
          letterSpacing: -0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _iconButton(
            icon: Icons.archive_outlined,
            tooltip: 'Archived classes',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArchivedClassesScreen()),
              ).then((_) => _loadSections());
            },
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.black54),
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.co_present_rounded,
                color: _Brand.tealMid,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active classes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No classes are set up for this term. Tap + to add one, or check the Archive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadSections,
      color: _Brand.teal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _sections.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) return _buildListHeader();
          final section = _sections[index - 1];
          return _buildSectionCard(section);
        },
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ACTIVE THIS TERM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
              letterSpacing: 0.7,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _Brand.tealSurf,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _Brand.tealBorder, width: 0.8),
            ),
            child: Text(
              '${_sections.length} ${_sections.length == 1 ? 'class' : 'classes'}',
              style: const TextStyle(
                fontSize: 11,
                color: _Brand.tealMid,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card ───────────────────────────────────────────────────────────

  Widget _buildSectionCard(Section section) {
    return Dismissible(
      key: ValueKey(section.id),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBackground(),
      confirmDismiss: (_) async {
        await _confirmAndDelete(section);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassRosterScreen(section: section),
              ),
            ).then((_) => _loadSections());
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Top row: grade badge + name/adviser + edit button
                Row(
                  children: [
                    _buildGradeBadge(section.gradeLevel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adviser: ${section.adviserName ?? 'Unassigned'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _cardIconButton(
                      icon: Icons.edit_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddSectionScreen(sectionToEdit: section),
                          ),
                        ).then((v) {
                          if (v == true) _loadSections();
                        });
                      },
                    ),
                  ],
                ),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: Colors.grey.shade100,
                  ),
                ),

                // Footer: gender counts + swipe hint
                Row(
                  children: [
                    _genderPill(
                      Icons.male_rounded,
                      Colors.blue.shade600,
                      Colors.blue.shade50,
                      section,
                    ),
                    const SizedBox(width: 14),
                    _genderPillFemale(section),
                    const SizedBox(width: 14),
                    _totalBadge(section),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_left_rounded,
                      size: 13,
                      color: Colors.black26,
                    ),
                    const Text(
                      'Swipe to delete',
                      style: TextStyle(fontSize: 11, color: Colors.black26),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeBadge(int gradeLevel) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _Brand.tealSurf,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          'G$gradeLevel',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _Brand.tealDark,
          ),
        ),
      ),
    );
  }

  Widget _cardIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: Colors.black45),
      ),
    );
  }

  Widget _genderPill(
    IconData icon,
    Color iconColor,
    Color bg,
    Section section,
  ) {
    return FutureBuilder<Map<String, int>>(
      future: _sectionRepo.getGenderCounts(section.id),
      builder: (context, snap) {
        final males = snap.data?['males'] ?? 0;
        return Row(
          children: [
            Icon(icon, size: 15, color: _Brand.blueText),
            const SizedBox(width: 3),
            Text(
              '$males',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Brand.blueText,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _genderPillFemale(Section section) {
    return FutureBuilder<Map<String, int>>(
      future: _sectionRepo.getGenderCounts(section.id),
      builder: (context, snap) {
        final females = snap.data?['females'] ?? 0;
        return Row(
          children: [
            Icon(Icons.female_rounded, size: 15, color: _Brand.pinkText),
            const SizedBox(width: 3),
            Text(
              '$females',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Brand.pinkText,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _totalBadge(Section section) {
    return FutureBuilder<Map<String, int>>(
      future: _sectionRepo.getGenderCounts(section.id),
      builder: (context, snap) {
        final total = (snap.data?['males'] ?? 0) + (snap.data?['females'] ?? 0);
        return Row(
          children: [
            const Text(
              'Total ',
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
            Text(
              '$total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Swipe Background ───────────────────────────────────────────────────────

  Widget _buildSwipeBackground() {
    return Container(
      decoration: BoxDecoration(
        color: _Brand.redSurf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Brand.redBorder, width: 0.8),
      ),
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.delete_outline_rounded, color: _Brand.redText, size: 22),
          SizedBox(height: 3),
          Text(
            'Delete',
            style: TextStyle(
              color: _Brand.redText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: _Brand.tealMid,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSectionScreen()),
        ).then((v) {
          if (v == true) _loadSections();
        });
      },
      child: const Icon(Icons.add_rounded),
    );
  }
}
