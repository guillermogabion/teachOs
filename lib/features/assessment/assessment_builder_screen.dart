import 'package:flutter/material.dart';
import '../attendance/repository/attendance_repository.dart';

class AssessmentBuilderScreen extends StatefulWidget {
  const AssessmentBuilderScreen({super.key});

  @override
  State<AssessmentBuilderScreen> createState() =>
      _AssessmentBuilderScreenState();
}

class _AssessmentBuilderScreenState extends State<AssessmentBuilderScreen> {
  final _attendanceRepo = AttendanceRepository();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assessment Builder Console'),
          backgroundColor: Colors.blueGrey.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_rounded), text: "Question Bank"),
              Tab(icon: Icon(Icons.copy_all_rounded), text: "Exam Templates"),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Context Target Header Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Target Course Context',
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

                  // Multi-Tier Feature Set Matrix Panels
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Viewport Tab 1: Question Bank Manager
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Draft Question Strategies:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('Multiple Choice'),
                                  onPressed: () {},
                                ),
                                ActionChip(
                                  label: const Text('True/False'),
                                  onPressed: () {},
                                ),
                                ActionChip(
                                  label: const Text('Identification'),
                                  onPressed: () {},
                                ),
                                ActionChip(
                                  label: const Text('Enumeration'),
                                  onPressed: () {},
                                ),
                                ActionChip(
                                  label: const Text('Essay Architecture'),
                                  onPressed: () {},
                                ),
                                ActionChip(
                                  label: const Text('Matching Type'),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Viewport Tab 2: Automation & Templates Configuration Setup
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.shuffle),
                              title: const Text('Randomization Rules Engine'),
                              subtitle: const Text(
                                'Generate unique variants for cheating mitigation',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                              ),
                              onTap: () {},
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.label_important_outline_rounded,
                              ),
                              title: const Text(
                                'Difficulty & Taxonomy Balancing',
                              ),
                              subtitle: const Text(
                                'Manage Easy / Medium / Hard ratio curves',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                              ),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
