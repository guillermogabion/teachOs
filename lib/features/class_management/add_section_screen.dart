import 'package:flutter/material.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';

class AddSectionScreen extends StatefulWidget {
  final Section? sectionToEdit;

  const AddSectionScreen({super.key, this.sectionToEdit});

  @override
  State<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends State<AddSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SectionRepository();

  // Removed _idController completely
  late TextEditingController _nameController;
  late TextEditingController _adviserController;
  late TextEditingController _syController;
  int _selectedGradeLevel = 7;

  bool get isEditMode => widget.sectionToEdit != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.sectionToEdit?.name ?? '',
    );
    _adviserController = TextEditingController(
      text: widget.sectionToEdit?.adviserName ?? '',
    );

    // DYNAMIC TIME ENGINE: Compute the active school year programmatically
    _syController = TextEditingController(
      text: widget.sectionToEdit?.schoolYearId ?? _calculateCurrentSchoolYear(),
    );

    if (isEditMode) {
      _selectedGradeLevel = widget.sectionToEdit!.gradeLevel;
    }
  }

  /// Calculates school year based on standard academic operational timelines
  String _calculateCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;

    // If the month is June (6) or later, we are starting the new academic cycle.
    // Otherwise, we are finishing the cycle that started the prior calendar year.
    if (now.month >= 6) {
      return '$year-${year + 1}'; // E.g., 2026-2027
    } else {
      return '${year - 1}-$year'; // E.g., 2025-2026
    }
  }

  void _saveSection() async {
    // 1. Check if the button tap is physically registering
    print('============= DEBUG: BUTTON TAPPED =============');

    if (_formKey.currentState == null) {
      print('============= DEBUG: Form State is NULL! =============');
      return;
    }

    // 2. Check if the validator is passing or failing
    bool isValid = _formKey.currentState!.validate();
    print(
      '============= DEBUG: FORM VALIDATION RESULT = $isValid =============',
    );

    if (isValid) {
      print(
        '============= DEBUG: Form valid! Preparing payload... =============',
      );

      final section = Section(
        id: isEditMode ? widget.sectionToEdit!.id : '',
        name: _nameController.text.trim(),
        gradeLevel: _selectedGradeLevel,
        adviserName: _adviserController.text.trim().isEmpty
            ? null
            : _adviserController.text.trim(),
        schoolYearId: _syController.text.trim(),
      );

      print(
        '============= DEBUG: Sending to database repository =============',
      );

      try {
        if (isEditMode) {
          await _repo.updateSection(section);
          print('============= DEBUG: DB Update Complete! =============');
        } else {
          await _repo.insertSection(section);
          print('============= DEBUG: DB Insert Complete! =============');
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('============= DATABASE CRASH ERROR: $e =============');
      }
    } else {
      print(
        '============= DEBUG: Validation blocked execution. Check UI text field errors! =============',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Class' : 'Create New Class'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // The unique ID TextFormField has been completely removed from here!
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Section / Class Name (e.g., Diamond, Ruby)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Section name is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedGradeLevel,
              decoration: const InputDecoration(
                labelText: 'Grade Level',
                border: OutlineInputBorder(),
              ),
              items: List.generate(12, (index) => index + 1)
                  .map(
                    (grade) => DropdownMenuItem(
                      value: grade,
                      child: Text('Grade $grade'),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGradeLevel = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adviserController,
              decoration: const InputDecoration(
                labelText: 'Assigned Adviser Teacher (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _syController,
              decoration: const InputDecoration(
                labelText: 'School Year Reference',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'School year is required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEditMode ? 'Save Class Configurations' : 'Create Class',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
