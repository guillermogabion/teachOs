import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';
import 'add_section_screen.dart';
import 'class_roster_screen.dart';
import 'archived_classes_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _sectionRepo = SectionRepository();
  final _localAuth = LocalAuthentication();
  List<Section> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final sections = await _sectionRepo.getActiveSections();
    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
  }

  Future<bool> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) return true;
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete this class',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> _confirmAndDelete(Section section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to permanently delete "${section.name}"?\n\n'
          'This will also remove all enrollments linked to this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // ✅ No refresh needed

    final authenticated = await _authenticate();
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Class was not deleted.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _sectionRepo.deleteSection(section.id);
    if (mounted) {
      setState(() {
        _sections.removeWhere((s) => s.id == section.id); // ✅ instant removal
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${section.name}" has been deleted.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Browse Archived Classes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArchivedClassesScreen(),
                ),
              ).then((_) => _loadSections()); // ✅ reload after archive screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
          ? const Center(
              child: Text(
                'No active classes for this term.\nTap + to add one or check the Archive.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Dismissible(
                  key: ValueKey(section.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade700,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, color: Colors.white),
                        SizedBox(height: 4),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    await _confirmAndDelete(section);
                    return false;
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: Text(
                          'G${section.gradeLevel}',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        section.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Adviser: ${section.adviserName ?? "Unassigned"}',
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<Map<String, int>>(
                            future: _sectionRepo.getGenderCounts(section.id),
                            builder: (context, genderSnapshot) {
                              if (genderSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                );
                              }
                              final counts =
                                  genderSnapshot.data ??
                                  {'males': 0, 'females': 0};
                              final total =
                                  counts['males']! + counts['females']!;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.male,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  Text(
                                    '${counts['males']}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.female,
                                    size: 16,
                                    color: Colors.pink.shade600,
                                  ),
                                  Text(
                                    '${counts['females']}',
                                    style: TextStyle(
                                      color: Colors.pink.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Total: $total',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddSectionScreen(sectionToEdit: section),
                            ),
                          ).then((value) {
                            if (value == true) _loadSections();
                          });
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ClassRosterScreen(section: section),
                          ),
                        ).then((_) => _loadSections());
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddSectionScreen()),
          ).then((value) {
            if (value == true) _loadSections();
          });
        },
      ),
    );
  }
}
