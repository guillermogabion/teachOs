import 'dart:async';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../class_management/models/section_model.dart';
import '../class_management/repositories/section_repository.dart';
import '../../../core/database/database_service.dart';

class RandomStudentPickerScreen extends StatefulWidget {
  const RandomStudentPickerScreen({super.key});

  @override
  State<RandomStudentPickerScreen> createState() =>
      _RandomStudentPickerScreenState();
}

class _RandomStudentPickerScreenState extends State<RandomStudentPickerScreen>
    with SingleTickerProviderStateMixin {
  final SectionRepository _sectionRepo = SectionRepository();

  late TabController _tabController;
  List<Section> _activeSections = [];
  List<Section> _archivedSections = [];
  Map<String, Map<String, int>> _sectionGenderStats = {};
  bool _loadingClasses = true;

  // Picker Engine Engine States
  Section? _selectedSection;
  List<Map<String, dynamic>> _currentClassRoster = [];
  List<Map<String, dynamic>> _remainingStudents = [];
  Map<String, dynamic>? _pickedStudent;
  bool _isShuffling = false;
  bool _loadingRoster = false;
  String? _errorMessage;

  // Wheel Motor Engine Variables
  final StreamController<int> _spinController =
      StreamController<int>.broadcast();
  int _winningIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _spinController.close();
    _tabController.dispose();
    super.dispose();
  }

  Color _getWheelColor(int index) {
    final colors = [
      Colors.pink.shade400,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.indigo.shade400,
      Colors.amber.shade500,
      Colors.cyan.shade600,
    ];
    return colors[index % colors.length];
  }

  Future<void> _loadInitialData() async {
    setState(() => _loadingClasses = true);
    try {
      final active = await _sectionRepo.getActiveSections();
      final archived = await _sectionRepo.getArchivedSections();

      Map<String, Map<String, int>> statsCache = {};
      for (var section in [...active, ...archived]) {
        final counts = await _sectionRepo.getGenderCounts(section.id);
        statsCache[section.id] = counts;
      }

      setState(() {
        _activeSections = active;
        _archivedSections = archived;
        _sectionGenderStats = statsCache;
        _loadingClasses = false;
      });
    } catch (e) {
      debugPrint('Database query exception: $e');
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadClassRoster(Section section) async {
    setState(() {
      _selectedSection = section;
      _loadingRoster = true;
      _pickedStudent = null;
      _errorMessage = null;
    });

    try {
      final db = await DatabaseService.instance.database;
      final List<Map<String, dynamic>> result = await db.rawQuery(
        '''
        SELECT s.* FROM enrollments e
        INNER JOIN students s ON e.student_id = s.id
        WHERE e.section_id = ?
      ''',
        [section.id],
      );

      if (mounted) {
        setState(() {
          _currentClassRoster = result;
          _remainingStudents = List.from(result);
          _loadingRoster = false;
        });
      }
    } catch (e) {
      debugPrint('Error pulling section roster: $e');
      if (mounted) {
        setState(() {
          _loadingRoster = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _spinWheel() {
    if (_remainingStudents.isEmpty) return;

    setState(() {
      _isShuffling = true;
      _pickedStudent = null;
      _winningIndex = Random().nextInt(_remainingStudents.length);
    });

    _spinController.add(_winningIndex);
  }

  void _resetRosterPool() {
    setState(() {
      _remainingStudents = List.from(_currentClassRoster);
      _pickedStudent = null;
    });
  }

  Widget _buildLastStudentCard() {
    final student = _remainingStudents.first;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_pin_rounded, size: 64, color: Colors.pink.shade300),
        const SizedBox(height: 16),
        Text(
          'ONE STUDENT REMAINING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (student['full_name'] ?? 'Unknown').toString().toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSection != null) {
      return _buildPickerEngineInterface();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Random Student Picker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.pink.shade600,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.pink.shade600,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active Classes'),
            Tab(text: 'Archived / Past Years'),
          ],
        ),
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClassGridList(_activeSections, isActivePool: true),
                _buildClassGridList(_archivedSections, isActivePool: false),
              ],
            ),
    );
  }

  Widget _buildClassGridList(
    List<Section> sections, {
    required bool isActivePool,
  }) {
    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isActivePool
                  ? 'No active classes configured for this school year.'
                  : 'No archived class structures detected.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final stats =
            _sectionGenderStats[section.id] ?? {'males': 0, 'females': 0};
        final totalCount = stats['males']! + stats['females']!;

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _loadClassRoster(section),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isActivePool ? Colors.pink : Colors.blueGrey)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.casino_rounded,
                      color: isActivePool
                          ? Colors.pink.shade600
                          : Colors.blueGrey.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${section.gradeLevel} - ${section.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                section.schoolYearId,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$totalCount Students total',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerEngineInterface() {
    final sectionTitle =
        '${_selectedSection!.gradeLevel} - ${_selectedSection!.name}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => setState(() => _selectedSection = null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionTitle,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'School Year ${_selectedSection!.schoolYearId}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
            tooltip: 'Reset Picking Pool',
            onPressed: _resetRosterPool,
          ),
        ],
      ),
      body: _loadingRoster
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Database Error:\n$_errorMessage',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _currentClassRoster.isEmpty
          ? _buildEmptyRosterNotice()
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Roster Remaining Counter Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'POOL RUNTIME: ${_remainingStudents.length} / ${_currentClassRoster.length} REMAINING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary Display: The Wheel (Wrapped in Expanded to fix overflow)
                  Expanded(
                    child: _remainingStudents.length < 2
                        ? Center(
                            child: _remainingStudents.isEmpty
                                ? Text(
                                    'ALL STUDENTS PICKED',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : _buildLastStudentCard(),
                          )
                        : _remainingStudents.isEmpty
                        ? Center(
                            child: Text(
                              'ALL STUDENTS PICKED',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : FortuneWheel(
                            selected: _spinController.stream,
                            animateFirst: false,
                            physics: CircularPanPhysics(
                              duration: const Duration(seconds: 4),
                              curve: Curves.decelerate,
                            ),
                            onAnimationEnd: () {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _pickedStudent =
                                      _remainingStudents[_winningIndex];
                                  _remainingStudents.removeAt(_winningIndex);
                                  _isShuffling = false;
                                });
                              });
                            },
                            items: [
                              for (
                                int i = 0;
                                i < _remainingStudents.length;
                                i++
                              )
                                FortuneItem(
                                  // Fixed "?" issue: Database uses 'full_name'
                                  // Added ConstrainedBox to fix text overflow
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Text(
                                      _remainingStudents[i]['full_name'] ??
                                          'Unknown',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  style: FortuneItemStyle(
                                    color: _getWheelColor(i),
                                    borderColor: Colors.white,
                                    borderWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Winner Announcement Card
                  if (_pickedStudent != null && !_isShuffling)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'WINNER!',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // Fixed "?" issue: Database uses 'full_name'
                            '${_pickedStudent!['full_name'] ?? 'Unknown'}'
                                .toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Empty placeholder to keep layout stable when no winner is shown
                    const SizedBox(height: 86),

                  const SizedBox(height: 24),

                  // Interaction Control Trigger Blocks
                  ElevatedButton(
                    onPressed: (_isShuffling || _remainingStudents.isEmpty)
                        ? null
                        : _spinWheel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _remainingStudents.isEmpty
                          ? 'POOL EXHAUSTED'
                          : _isShuffling
                          ? 'SPINNING...'
                          : 'SPIN THE WHEEL',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _isShuffling
                        ? null
                        : () => setState(() => _selectedSection = null),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                    child: const Text(
                      'Return to Class Selection',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyRosterNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Students Enrolled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'To execute recursive recitations, link records within the student directory database architecture first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
