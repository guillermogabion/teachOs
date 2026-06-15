import 'package:flutter/material.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';

class _Brand {
  static const Color teal = Colors.teal;
  static final Color greySurf = Colors.grey.shade50;
  static final Color greyBorder = Colors.grey.shade200;
}

class AddSectionScreen extends StatefulWidget {
  final Section? sectionToEdit;

  const AddSectionScreen({super.key, this.sectionToEdit});

  @override
  State<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends State<AddSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SectionRepository();

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
    _syController = TextEditingController(
      text: widget.sectionToEdit?.schoolYearId ?? _calculateCurrentSchoolYear(),
    );

    if (isEditMode) {
      _selectedGradeLevel = widget.sectionToEdit!.gradeLevel;
    }
  }

  String _calculateCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;

    if (now.month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  void _saveSection() async {
    debugPrint('============= DEBUG: BUTTON TAPPED =============');

    if (_formKey.currentState == null) {
      debugPrint('============= DEBUG: Form State is NULL! =============');
      return;
    }

    bool isValid = _formKey.currentState!.validate();
    debugPrint(
      '============= DEBUG: FORM VALIDATION RESULT = $isValid =============',
    );

    if (isValid) {
      debugPrint(
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

      debugPrint(
        '============= DEBUG: Sending to database repository =============',
      );

      try {
        if (isEditMode) {
          await _repo.updateSection(section);
          debugPrint('============= DEBUG: DB Update Complete! =============');
        } else {
          await _repo.insertSection(section);
          debugPrint('============= DEBUG: DB Insert Complete! =============');
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('============= DATABASE CRASH ERROR: $e =============');
      }
    } else {
      debugPrint(
        '============= DEBUG: Validation blocked execution. Check UI text field errors! =============',
      );
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.black45),
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Colors.black45,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: _Brand.teal,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      fillColor: Colors.white,
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _Brand.greyBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: _Brand.greyBorder),
        ),
        title: Text(
          isEditMode ? 'Edit Class Configurations' : 'Create New Class',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Field: Class Name
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                label: 'Section / Class Name (e.g., Diamond, Ruby)',
                icon: Icons.class_outlined,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Section name is required' : null,
            ),
            const SizedBox(height: 16),

            // Field: Dropdown Grade Level
            DropdownButtonFormField<int>(
              value: _selectedGradeLevel,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black45,
              ),
              decoration: _buildInputDecoration(
                label: 'Grade Level Mapping',
                icon: Icons.layers_outlined,
              ),
              items: List.generate(12, (index) => index + 1)
                  .map(
                    (grade) => DropdownMenuItem(
                      value: grade,
                      child: Text(
                        'Grade $grade',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGradeLevel = val);
              },
            ),
            const SizedBox(height: 16),

            // Field: Adviser Teacher Name
            TextFormField(
              controller: _adviserController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                label: 'Assigned Adviser Teacher (Optional)',
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),

            // Field: School Year Tracking
            TextFormField(
              controller: _syController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                label: 'School Year Reference',
                icon: Icons.date_range_rounded,
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'School year identifier is required'
                  : null,
            ),
            const SizedBox(height: 32),

            // Commit/Save Action Trigger
            ElevatedButton(
              onPressed: _saveSection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                isEditMode ? 'Save Class Configurations' : 'Create Class Block',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
