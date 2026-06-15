import 'package:flutter/material.dart';
import 'models/student_model.dart';
import 'repositories/student_repository.dart';

// ─── Brand palette (shared across TeachOS screens) ────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);

  static const amberSurf = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF854F0B);
  static const amberBorder = Color(0xFFFAC775);
}
// ─────────────────────────────────────────────────────────────────────────────

class AddStudentScreen extends StatefulWidget {
  final Student? studentToEdit;

  const AddStudentScreen({super.key, this.studentToEdit});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = StudentRepository();

  late TextEditingController _nameController;
  late TextEditingController _parentContactController;
  late TextEditingController _addressController;
  late TextEditingController _middleNameController;
  late TextEditingController _birthdateController;

  String? _selectedGender;
  bool get isEditMode => widget.studentToEdit != null;
  bool _requireExtraData = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.studentToEdit?.fullName ?? '',
    );
    _parentContactController = TextEditingController(
      text: widget.studentToEdit?.parentContact ?? '',
    );
    _addressController = TextEditingController(
      text: widget.studentToEdit?.address ?? '',
    );
    _middleNameController = TextEditingController(
      text: widget.studentToEdit?.middleName ?? '',
    );
    _birthdateController = TextEditingController(
      text: widget.studentToEdit?.birthdate ?? '',
    );
    _selectedGender = widget.studentToEdit?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentContactController.dispose();
    _addressController.dispose();
    _middleNameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthdate() async {
    DateTime initialDate = DateTime.now().subtract(
      const Duration(days: 365 * 6),
    );
    if (_birthdateController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdateController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _Brand.tealMid,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdateController.text = picked.toString().split(' ')[0];
      });
    }
  }

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      if (!isEditMode && !_requireExtraData) {
        final duplicates = await _repo.checkPotentialDuplicates(
          _nameController.text.trim(),
          _parentContactController.text.trim(),
        );

        if (duplicates.isNotEmpty) {
          _showDuplicateModal(duplicates.first);
          return;
        }
      }

      final student = Student(
        id: isEditMode ? widget.studentToEdit!.id : null,
        fullName: _nameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        birthdate: _birthdateController.text.trim(),
        gender: _selectedGender,
        parentContact: _parentContactController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (isEditMode) {
        await _repo.updateStudent(student);
      } else {
        await _repo.insertStudent(student);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Record updated successfully!'
                  : 'Student registered successfully!',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: _Brand.tealDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  void _showDuplicateModal(Student duplicateRecord) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: _Brand.amberText,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Data Already Exists',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A student matching these details is already in the database:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _Brand.amberSurf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _Brand.amberBorder, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name: ${duplicateRecord.fullName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _Brand.amberText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: ${duplicateRecord.parentContact}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Is this a different person? If yes, click below to supply unique identifying credentials.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'No, cancel',
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _requireExtraData = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.tealMid,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Yes, add new person',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(
    String label, {
    IconData? icon,
    Color? focusColor,
    Color? fillColor,
  }) {
    final activeFocusColor = focusColor ?? _Brand.tealMid;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.black45),
      prefixIcon: icon != null
          ? Icon(icon, color: activeFocusColor, size: 18)
          : null,
      filled: true,
      fillColor: fillColor ?? Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: activeFocusColor, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 0.8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
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
        title: Text(
          isEditMode ? 'Edit Student Details' : 'Register New Student',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                'Full Name',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            if (_requireExtraData) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Brand.amberSurf,
                  border: Border.all(color: _Brand.amberBorder, width: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _Brand.amberText,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verification Details Required',
                            style: TextStyle(
                              color: _Brand.amberText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _middleNameController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: _buildInputDecoration(
                        'Complete Middle Name',
                        focusColor: _Brand.amberText,
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Middle name is required for unique verification'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _birthdateController,
                      readOnly: true,
                      onTap: _selectBirthdate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: _buildInputDecoration(
                        'Birthdate (YYYY-MM-DD)',
                        icon: Icons.calendar_today_rounded,
                        focusColor: _Brand.amberText,
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Birthdate is required for unique verification'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            DropdownButtonFormField<String>(
              value: _selectedGender,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              dropdownColor: Colors.white,
              decoration: _buildInputDecoration(
                'Gender',
                icon: Icons.wc_rounded,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a gender' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _parentContactController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                'Parent/Guardian Contact',
                icon: Icons.phone_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _buildInputDecoration(
                'Home Address',
                icon: Icons.home_outlined,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.tealMid,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                isEditMode
                    ? 'Update Database Record'
                    : _requireExtraData
                    ? 'Save Verified Record'
                    : 'Save Student Record',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
