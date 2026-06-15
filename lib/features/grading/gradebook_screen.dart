import 'package:flutter/material.dart';
import '../attendance/repository/attendance_repository.dart';
import './grade_category_screen.dart';
import './weights_formulas_screen.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
}

// ─── Reusable Input Decoration ────────────────────────────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class GradebookScreen extends StatefulWidget {
  const GradebookScreen({super.key});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
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
    setState(() {
      _sections = data;
      if (data.isNotEmpty) _selectedSectionId = data.first['id'];
      _isLoading = false;
    });
  }

  void _navigateToCategory(String categoryName) {
    if (_selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCategoryScreen(
          sectionId: _selectedSectionId!,
          categoryName: categoryName,
        ),
      ),
    );
  }

  void _navigateToWeights() {
    if (_selectedSectionId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WeightsAndFormulasScreen(sectionId: _selectedSectionId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Gradebook Engine',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                // Class Selector
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: _buildInputDecoration(
                      labelText: 'Select Class/Section',
                    ),
                    value: _selectedSectionId,
                    items: _sections
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedSectionId = val),
                  ),
                ),

                // Grid View
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildSubFeatureCard(
                        'Seatwork Log',
                        Icons.menu_book,
                        () => _navigateToCategory('Seatwork'),
                      ),
                      _buildSubFeatureCard(
                        'Assignments',
                        Icons.assignment_turned_in,
                        () => _navigateToCategory('Assignment'),
                      ),
                      _buildSubFeatureCard(
                        'Project Registry',
                        Icons.assignment,
                        () => _navigateToCategory('Project'),
                      ),
                      _buildSubFeatureCard(
                        'Quiz Ledger',
                        Icons.timer,
                        () => _navigateToCategory('Quiz'),
                      ),
                      _buildSubFeatureCard(
                        'Major Exams',
                        Icons.workspace_premium,
                        () => _navigateToCategory('Exam'),
                      ),
                      _buildSubFeatureCard(
                        'Formulas',
                        Icons.calculate_rounded,
                        _navigateToWeights,
                      ),
                    ],
                  ),
                ),

                // Export Dock
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Export PDF'),
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _Brand.tealDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.table_view, size: 18),
                          label: const Text('Export Excel'),
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _Brand.tealMid,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSubFeatureCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _Brand.tealSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Brand.teal.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: _Brand.tealDark),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _Brand.tealDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
