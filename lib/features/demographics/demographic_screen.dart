import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../attendance/repository/attendance_repository.dart';

class StudentDemographicsScreen extends StatefulWidget {
  const StudentDemographicsScreen({super.key});

  @override
  State<StudentDemographicsScreen> createState() =>
      _StudentDemographicsScreenState();
}

class _StudentDemographicsScreenState extends State<StudentDemographicsScreen>
    with RestorationMixin<StudentDemographicsScreen> {
  final RestorableString _demographicsScreen = RestorableString('');
  final _attendanceRepo = AttendanceRepository();
  bool _isLoading = true;

  // Integrated Metric States
  int _totalEnrolled = 0;
  int _males = 0;
  int _females = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  List<Map<String, dynamic>> _classMetrics = [];

  // Active Cross-Filter Targets
  String _selectedGender = 'All';
  String _selectedSchoolYear = 'All';
  DateTime? _selectedDate = DateTime.now();
  String _selectedMonth = 'All';
  String _selectedYear = 'All';

  final List<Map<String, String>> _monthsList = [
    {'value': 'All', 'label': 'All Months'},
    {'value': '01', 'label': 'January'},
    {'value': '02', 'label': 'February'},
    {'value': '03', 'label': 'March'},
    {'value': '04', 'label': 'April'},
    {'value': '05', 'label': 'May'},
    {'value': '06', 'label': 'June'},
    {'value': '07', 'label': 'July'},
    {'value': '08', 'label': 'August'},
    {'value': '09', 'label': 'September'},
    {'value': '10', 'label': 'October'},
    {'value': '11', 'label': 'November'},
    {'value': '12', 'label': 'December'},
  ];

  @override
  String? get restorationId => 'demographics_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_demographicsScreen, 'demographics_screen');
  }

  @override
  void initState() {
    super.initState();
    _fetchUnifiedAnalytics();
  }

  Future<void> _fetchUnifiedAnalytics() async {
    setState(() => _isLoading = true);
    try {
      String? formattedDate = _selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
          : null;

      final data = await _attendanceRepo.getAdvancedAnalytics(
        schoolYear: _selectedSchoolYear,
        gender: _selectedGender,
        targetDate: formattedDate,
        targetMonth: _selectedMonth == 'All' ? null : _selectedMonth,
        targetYear: _selectedYear == 'All' ? null : _selectedYear,
      );

      setState(() {
        _totalEnrolled = data['totalEnrolled'] ?? 0;
        _males = data['males'] ?? 0;
        _females = data['females'] ?? 0;
        _presentCount = data['presentToday'] ?? 0;
        _absentCount = data['absentToday'] ?? 0;
        _classMetrics = List<Map<String, dynamic>>.from(data['classes'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Analytics pipeline execution failure: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- UI CONSTANTS ---
  final _borderRadius = BorderRadius.circular(16);
  final _inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    labelStyle: const TextStyle(fontSize: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUnifiedAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildControlFilteringMatrix(),
                  const SizedBox(height: 20),
                  _buildRealtimeAttendanceRow(),
                  const SizedBox(height: 20),
                  _buildDemographicSummaryCard(),
                  const SizedBox(height: 20),
                  _buildPieChartVisualizer(),
                  const SizedBox(height: 20),
                  _buildClassDistributionBarChart(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildControlFilteringMatrix() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          "Filter Parameters",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.filter_list_rounded),
        shape: const Border(),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _inputDecoration.copyWith(labelText: 'Gender'),
                  items: ['All', 'Male', 'Female']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedGender = val!;
                    _fetchUnifiedAnalytics();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSchoolYear,
                  decoration: _inputDecoration.copyWith(labelText: 'SY'),
                  items: ['All', '2024-2025', '2025-2026']
                      .map((sy) => DropdownMenuItem(value: sy, child: Text(sy)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedSchoolYear = val!;
                    _fetchUnifiedAnalytics();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth,
                  decoration: _inputDecoration.copyWith(labelText: 'Month'),
                  items: _monthsList
                      .map(
                        (m) => DropdownMenuItem(
                          value: m['value'],
                          child: Text(m['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedMonth = val!;
                    _selectedDate = null;
                    _fetchUnifiedAnalytics();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: _inputDecoration.copyWith(labelText: 'Year'),
                  items: ['All', '2025', '2026']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedYear = val!;
                    _selectedDate = null;
                    _fetchUnifiedAnalytics();
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeAttendanceRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            'Present',
            '$_presentCount',
            Colors.teal,
            Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricTile(
            'Absent',
            '$_absentCount',
            Colors.redAccent,
            Icons.cancel_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: _borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enrolment Overview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatSubColumn('Total', '$_totalEnrolled', Colors.black87),
                _buildStatSubColumn('Males', '$_males', Colors.blue),
                _buildStatSubColumn('Females', '$_females', Colors.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSubColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildPieChartVisualizer() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Ratio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: Colors.teal,
                      value: _presentCount.toDouble(),
                      title: '',
                      radius: 30,
                    ),
                    PieChartSectionData(
                      color: Colors.redAccent,
                      value: _absentCount.toDouble(),
                      title: '',
                      radius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassDistributionBarChart() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Distribution',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(_classMetrics.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (_classMetrics[index]['classCount'] as int? ?? 0)
                              .toDouble(),
                          color: Colors.indigo,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  // ... inside _buildClassDistributionBarChart
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      // INCREASE reservedSize so the rotated labels aren't clipped
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize:
                            40, // Adjust this value to accommodate your label length
                        getTitlesWidget: (val, meta) {
                          final label = _classMetrics[val.toInt()]['className']
                              .toString();

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Transform.rotate(
                              angle:
                                  -0.5, // Adjust rotation angle (e.g., -0.5 radians ≈ -28 degrees)
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  // ...
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
