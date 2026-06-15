import 'package:flutter/material.dart';

class WeightsAndFormulasScreen extends StatefulWidget {
  final String sectionId;

  const WeightsAndFormulasScreen({super.key, required this.sectionId});

  @override
  State<WeightsAndFormulasScreen> createState() =>
      _WeightsAndFormulasScreenState();
}

class _WeightsAndFormulasScreenState extends State<WeightsAndFormulasScreen> {
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

  void _loadExistingWeights() {
    // TODO: Fetch from `grade_categories` table based on widget.sectionId
    // If weights exist, update the controllers here.
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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Execute SQLite UPDATE/INSERT into grade_categories table

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grading formulas saved successfully.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Weights & Formulas'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Define Grading Criteria',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the percentage weight for each category. The total must equal 100%.',
          ),
          const SizedBox(height: 24),

          ..._controllers.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16.0),
              child: TextField(
                controller: entry.value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: entry.key,
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),

          const Divider(height: 32, thickness: 2),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Weight:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '$_currentTotal%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _currentTotal == 100 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _currentTotal == 100 ? _saveWeights : null,
            child: const Text(
              'Save Configuration',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
