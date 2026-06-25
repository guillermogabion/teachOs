import 'package:flutter/material.dart';
import '../../features/class_management/models/section_model.dart';
import '../../features/class_management/repositories/section_repository.dart';
import './class_gradebook_screen.dart';

// ─── Brand palette (shared with GradebookScreen) ──────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);
}
// ─────────────────────────────────────────────────────────────────────────────

/// Classes from past school years. A class lands here automatically once
/// SectionRepository's current-school-year calculation moves past it —
/// the same rule the Class Management module already uses.
class ArchivedGradebookScreen extends StatefulWidget {
  const ArchivedGradebookScreen({super.key});

  @override
  State<ArchivedGradebookScreen> createState() =>
      _ArchivedGradebookScreenState();
}

class _ArchivedGradebookScreenState extends State<ArchivedGradebookScreen>
    with RestorationMixin<ArchivedGradebookScreen> {
  final RestorableString _archivedGradebookScreen = RestorableString('');
  final _sectionRepo = SectionRepository();

  List<Section> _sections = [];
  bool _isLoading = true;

  @override
  String? get restorationId => 'archived_gradebook_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(
      _archivedGradebookScreen,
      'archived_gradebook_screen',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final sections = await _sectionRepo.getArchivedSections();
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
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
          : _buildGroupedList(),
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
      title: const Text(
        'Archived gradebooks',
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
                Icons.archive_outlined,
                color: _Brand.tealMid,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No archived classes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Classes from past school years will show up here once a new term begins.',
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

  // ── Grouped List (by School Year) ─────────────────────────────────────────

  Widget _buildGroupedList() {
    // Repo already orders by school_year_id DESC, so a simple consecutive
    // grouping preserves newest-to-oldest ordering without re-sorting.
    final List<MapEntry<String, List<Section>>> groups = [];
    for (final section in _sections) {
      if (groups.isNotEmpty && groups.last.key == section.schoolYearId) {
        groups.last.value.add(section);
      } else {
        groups.add(MapEntry(section.schoolYearId, [section]));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadSections,
      color: _Brand.teal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildYearHeader(group.key, group.value.length),
                const SizedBox(height: 10),
                ...group.value.map(_buildClassCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearHeader(String schoolYearId, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'S.Y. $schoolYearId',
          style: const TextStyle(
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
            '$count ${count == 1 ? 'class' : 'classes'}',
            style: const TextStyle(
              fontSize: 11,
              color: _Brand.tealMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Class Card ─────────────────────────────────────────────────────────────

  Widget _buildClassCard(Section section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassGradebookScreen(section: section),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
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
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.black26,
              ),
            ],
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
}
