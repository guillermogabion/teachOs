import 'package:flutter/material.dart';
import 'repositories/enrollment_repository.dart'; // Ensure this points to your actual repository file

class AddStudentBottomSheet extends StatefulWidget {
  final String sectionId;
  final VoidCallback
  onStudentAdded; // Triggers a UI refresh on the parent screen

  const AddStudentBottomSheet({
    super.key,
    required this.sectionId,
    required this.onStudentAdded,
  });

  @override
  State<AddStudentBottomSheet> createState() => _AddStudentBottomSheetState();
}

class _AddStudentBottomSheetState extends State<AddStudentBottomSheet> {
  // TODO: Initialize your repository here
  final _repo = EnrollmentRepository();

  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() => _isSearching = true);

    try {
      // Execute the dynamic search query
      final results = await _repo.searchUnenrolledStudents(
        widget.sectionId,
        query,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _enrollSelectedStudent(
    String studentId,
    String studentName,
  ) async {
    await _repo.enrollStudent(widget.sectionId, studentId);

    if (mounted) {
      // Clear the search bar and results so they can add another student immediately
      _searchCtrl.clear();
      setState(() => _searchResults.clear());

      // Notify parent screen to update its list
      widget.onStudentAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$studentName added to class successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Defines a fixed height for the bottom sheet
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.7, // Takes up 70% of the screen
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Student to Class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Search Bar
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by student name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged(''); // Clear results
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged:
                _onSearchChanged, // Triggers the database query instantly
          ),
          const SizedBox(height: 16),

          // Autocomplete Results List
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchCtrl.text.isEmpty
                ? Center(
                    child: Text(
                      'Type a name to search the global directory.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Text(
                      'No matching unenrolled students found.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(
                            Icons.person,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        title: Text(
                          student['full_name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          onPressed: () => _enrollSelectedStudent(
                            student['id'],
                            student['full_name'],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
