import 'package:flutter/material.dart';
import 'repositories/enrollment_repository.dart';

// Consistent Branding
class _Brand {
  static const Color teal = Colors.teal;
  static final Color tealSurf = Colors.teal.shade50;
  static final Color greySurf = Colors.grey.shade50;
  static final Color greyBorder = Colors.grey.shade200;
}

class AddStudentBottomSheet extends StatefulWidget {
  final String sectionId;
  final VoidCallback onStudentAdded;

  const AddStudentBottomSheet({
    super.key,
    required this.sectionId,
    required this.onStudentAdded,
  });

  @override
  State<AddStudentBottomSheet> createState() => _AddStudentBottomSheetState();
}

class _AddStudentBottomSheetState extends State<AddStudentBottomSheet> {
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
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
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
      debugPrint("============= SEARCH ERROR: $e =============");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _enrollSelectedStudent(
    String studentId,
    String studentName,
  ) async {
    await _repo.enrollStudent(widget.sectionId, studentId);

    if (mounted) {
      _searchCtrl.clear();
      setState(() => _searchResults.clear());
      widget.onStudentAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$studentName added to class successfully!'),
          backgroundColor: _Brand.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Student',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by student name...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: _Brand.greySurf,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: _Brand.teal),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchCtrl.text.isEmpty
                              ? 'Enter a name to search'
                              : 'No students found',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = _searchResults[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _Brand.tealSurf,
                          child: Text(
                            student['full_name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: _Brand.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          student['full_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _enrollSelectedStudent(
                            student['id'],
                            student['full_name'],
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: _Brand.tealSurf,
                            foregroundColor: _Brand.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Add'),
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
