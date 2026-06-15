import 'package:flutter/material.dart';
import 'models/student_model.dart';
import 'repositories/student_repository.dart';

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

  // NEW: Controllers for unique identity
  late TextEditingController _middleNameController;
  late TextEditingController _birthdateController;

  String? _selectedGender;
  bool get isEditMode => widget.studentToEdit != null;

  // NEW: State to track if we need to show the unique fields
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

    // Initialize new controllers (assuming your model is updated to handle them)
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

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      // STEP 1: Duplicate Check (Only if creating new & haven't verified yet)
      if (!isEditMode && !_requireExtraData) {
        final duplicates = await _repo.checkPotentialDuplicates(
          _nameController.text.trim(),
          _parentContactController.text.trim(),
        );

        if (duplicates.isNotEmpty) {
          _showDuplicateModal(duplicates.first);
          return; // Stop execution here, wait for user resolution
        }
      }

      // STEP 2: Save the Data
      final student = Student(
        id: isEditMode ? widget.studentToEdit!.id : null,
        fullName: _nameController.text.trim(),
        // Add the new fields to your model construction
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
              isEditMode ? 'Record updated!' : 'Student registered!',
            ),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  // NEW: The Modal Logic
  void _showDuplicateModal(Student duplicateRecord) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to click a button
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Data Already Exists',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
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
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name: ${duplicateRecord.fullName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: ${duplicateRecord.parentContact}',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Is this a new person? If yes, we need to add unique details.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'No, cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _requireExtraData = true; // This will trigger a UI rebuild
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Yes, add new person',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.teal.shade700) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Student Details' : 'Register New Student',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _buildInputDecoration(
                'Full Name',
                icon: Icons.person_outline,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),

            // --- NEW: Conditionally rendered fields for unique identity ---
            if (_requireExtraData) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please provide identifiers to prevent duplicates.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _middleNameController,
                      decoration: InputDecoration(
                        labelText: 'Complete Middle Name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Middle name is required for unique ID'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _birthdateController,
                      decoration: InputDecoration(
                        labelText: 'Birthdate (YYYY-MM-DD)',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Birthdate is required for unique ID'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: _buildInputDecoration(
                'Gender',
                icon: Icons.wc_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a gender' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _parentContactController,
              decoration: _buildInputDecoration(
                'Parent/Guardian Contact',
                icon: Icons.phone_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _addressController,
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
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEditMode
                    ? 'Update Database Record'
                    : _requireExtraData
                    ? 'Save Unique Student Record'
                    : 'Save Student Record',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
