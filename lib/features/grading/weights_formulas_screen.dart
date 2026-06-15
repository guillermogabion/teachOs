import 'package:flutter/material.dart';
import 'repository/gradebook_repository.dart';

// ─── Brand Palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const amberWarning = Color(0xFFD97706);
  static const redText = Color(0xFFDC2626);
}

// ─── Reusable Input Decoration ────────────────────────────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    suffix: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class WeightsAndFormulasScreen extends StatefulWidget {
  final String sectionId;

  const WeightsAndFormulasScreen({super.key, required this.sectionId});

  @override
  State<WeightsAndFormulasScreen> createState() =>
      _WeightsAndFormulasScreenState();
}

class _WeightsAndFormulasScreenState extends State<WeightsAndFormulasScreen> {
  final _gradeRepo = GradebookRepository();
  bool _isLoading = false;

  // Controllers to handle text input for percentages
  final Map<String, TextEditingController> _controllers = {
    'Seatwork': TextEditingController(text: '0'),
    'Assignment': TextEditingController(text: '0'),
    'Project': TextEditingController(text: '0'),
    'Quiz': TextEditingController(text: '0'),
    'Exam': TextEditingController(text: '0'),
  };

  int _currentTotal = 0;

  @override
  void initState() {
    super.initState();
    // Listen to changes to dynamically calculate the total
    for (var controller in _controllers.values) {
      controller.addListener(_calculateTotal);
    }
    _loadExistingWeights();
  }

  Future<void> _loadExistingWeights() async {
    // Hooks clean entry point for SQLite/Repository reads
    // TODO: Fetch from `grade_categories` table based on widget.sectionId
    // If weights exist, update the controllers here.
    _calculateTotal();
  }

  void _calculateTotal() {
    int sum = 0;
    for (var controller in _controllers.values) {
      sum += int.tryParse(controller.text) ?? 0;
    }
    setState(() => _currentTotal = sum);
  }

  Future<void> _saveWeights() async {
    if (_currentTotal != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weights must equal exactly 100%'),
          backgroundColor: _Brand.redText,
        ),
      );
      return;
    }

    // TODO: Execute SQLite UPDATE/INSERT into grade_categories table using _gradeRepo

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grading formulas saved successfully.'),
          backgroundColor: _Brand.tealDark,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Weights & Formulas',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Define Grading Criteria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _Brand.tealDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Assign relative percentage weights to each category component. The combined total must equal exactly 100% to save.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                ..._controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    child: TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      decoration: _buildInputDecoration(
                        labelText: entry.key,
                        suffix: const Text(
                          '%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _Brand.tealMid,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _currentTotal == 100
                        ? _Brand.tealSurf
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentTotal == 100
                          ? _Brand.teal.withOpacity(0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Combined Weight',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '$_currentTotal%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _currentTotal == 100
                              ? _Brand.tealMid
                              : _Brand.amberWarning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _Brand.tealDark,
              disabledBackgroundColor: Colors.grey.shade200,
              disabledForegroundColor: Colors.black38,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _currentTotal == 100 ? _saveWeights : null,
            child: const Text(
              'Save Configuration',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
