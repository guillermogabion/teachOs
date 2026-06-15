import 'package:flutter/material.dart';
import '../attendance/repository/attendance_repository.dart';

// ─── Brand Palette Tokens ────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
  static const bgSurface = Color(0xFFF9FAFB);
}

// ─── Reusable Input Decoration Helper ────────────────────────────────────────
InputDecoration _buildInputDecoration({required String labelText}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
    ),
  );
}

class AssessmentBuilderScreen extends StatefulWidget {
  const AssessmentBuilderScreen({super.key});

  @override
  State<AssessmentBuilderScreen> createState() =>
      _AssessmentBuilderScreenState();
}

class _AssessmentBuilderScreenState extends State<AssessmentBuilderScreen> {
  final _attendanceRepo = AttendanceRepository();
  String? _selectedSectionId;
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final data = await _attendanceRepo.getAvailableSections();
    if (mounted) {
      setState(() {
        _sections = data;
        if (data.isNotEmpty) _selectedSectionId = data.first['id'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Assessment Builder Console',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _Brand.charcoal,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            indicatorColor: _Brand.teal,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
            labelColor: _Brand.tealDark,
            unselectedLabelColor: _Brand.mutedText,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.inventory_2_rounded, size: 20),
                text: "Question Bank",
                iconMargin: EdgeInsets.fromLTRB(0, 0, 0, 4),
              ),
              Tab(
                icon: Icon(Icons.copy_all_rounded, size: 20),
                text: "Exam Templates",
                iconMargin: EdgeInsets.fromLTRB(0, 0, 0, 4),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
            : Column(
                children: [
                  // Context Target Header Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _Brand.bgSurface,
                    child: DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration(
                        labelText: 'Target Course Context',
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Brand.charcoal,
                      ),
                      value: _selectedSectionId,
                      items: _sections.map((s) {
                        return DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSectionId = val);
                      },
                    ),
                  ),

                  // Tab View Panels
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Viewport Tab 1: Question Bank Manager
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text(
                              'Draft Question Strategies',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _Brand.tealDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Select a framework below to begin composing active test items.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _Brand.mutedText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildStrategyChip(
                                  label: 'Multiple Choice',
                                  onPressed: () {},
                                ),
                                _buildStrategyChip(
                                  label: 'True/False',
                                  onPressed: () {},
                                ),
                                _buildStrategyChip(
                                  label: 'Identification',
                                  onPressed: () {},
                                ),
                                _buildStrategyChip(
                                  label: 'Enumeration',
                                  onPressed: () {},
                                ),
                                _buildStrategyChip(
                                  label: 'Essay Architecture',
                                  onPressed: () {},
                                ),
                                _buildStrategyChip(
                                  label: 'Matching Type',
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Viewport Tab 2: Automation Setup
                        ListView(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          children: [
                            _buildTemplateTile(
                              icon: Icons.shuffle_rounded,
                              title: 'Randomization Rules Engine',
                              subtitle:
                                  'Generate unique variants for cheating mitigation',
                              onTap: () {},
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(
                                color: Color(0xFFF3F4F6),
                                thickness: 1.2,
                              ),
                            ),
                            _buildTemplateTile(
                              icon: Icons.label_important_outline_rounded,
                              title: 'Difficulty & Taxonomy Balancing',
                              subtitle:
                                  'Manage Easy / Medium / Hard ratio curves',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStrategyChip({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: _Brand.tealDark,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: _Brand.tealSurf,
      side: BorderSide.none,
      elevation: 0,
      pressElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: onPressed,
    );
  }

  Widget _buildTemplateTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _Brand.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(icon, color: _Brand.tealMid, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: _Brand.charcoal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: _Brand.mutedText,
          height: 1.3,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: Colors.black26,
      ),
      onTap: onTap,
    );
  }
}
