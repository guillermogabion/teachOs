import 'package:flutter/material.dart';
import '../attendance/repository/attendance_repository.dart';
import './grade_category_screen.dart';
import './weights_formulas_screen.dart';

class GradebookScreen extends StatefulWidget {
  const GradebookScreen({super.key});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  final _attendanceRepo =
      AttendanceRepository(); // Repurposed to read shared sections
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
      appBar: AppBar(
        title: const Text('Dynamic Gradebook Engine'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Class Selector Row
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Class Matrix View',
                      border: OutlineInputBorder(),
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

                // Activities Quick Links Grid View
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
                        'Major Examinations',
                        Icons.workspace_premium,
                        () => _navigateToCategory('Exam'),
                      ),
                      _buildSubFeatureCard(
                        'Weights & Formulas',
                        Icons.calculate_rounded,
                        _navigateToWeights,
                      ),
                    ],
                  ),
                ),

                // Export and Calculation Engine Dashboard Dock
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                        onPressed: () {},
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.table_view),
                        label: const Text('Export Excel'),
                        onPressed: () {},
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
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.teal.shade700),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
