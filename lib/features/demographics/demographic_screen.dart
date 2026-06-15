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

class _StudentDemographicsScreenState extends State<StudentDemographicsScreen> {
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
  DateTime? _selectedDate = DateTime.now(); // Defaults to today
  String _selectedMonth = 'All';
  String _selectedYear = 'All';

  // Month Mapping Dataset for the dropdown
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
  void initState() {
    super.initState();
    _fetchUnifiedAnalytics();
  }

  Future<void> _fetchUnifiedAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // If a specific day filter is selected, format it for SQLite (YYYY-MM-DD)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'System Analytics Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildControlFilteringMatrix(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchUnifiedAnalytics,
                    color: Colors.blueAccent,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildRealtimeAttendanceRow(),
                        const SizedBox(height: 16),
                        _buildDemographicSummaryCard(),
                        const SizedBox(height: 16),
                        _buildPieChartVisualizer(),
                        const SizedBox(height: 16),
                        _buildClassDistributionBarChart(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlFilteringMatrix() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12.0),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          "Search Filters & Parameters",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.tune_rounded, color: Colors.blueAccent),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Row 1: Gender & School Year
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        items: ['All', 'Male', 'Female']
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedGender = val!;
                          _fetchUnifiedAnalytics();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSchoolYear,
                        decoration: const InputDecoration(
                          labelText: 'School Year',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        items: ['All', '2024-2025', '2025-2026', '2026-2027']
                            .map(
                              (sy) =>
                                  DropdownMenuItem(value: sy, child: Text(sy)),
                            )
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

                // Row 2: Month & Year (Added missing layout fields to fix stick states)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
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
                          _selectedDate =
                              null; // Clear day selection to avoid collision
                          _fetchUnifiedAnalytics();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        items: ['All', '2024', '2025', '2026', '2027']
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedYear = val!;
                          _selectedDate =
                              null; // Clear day selection to avoid collision
                          _fetchUnifiedAnalytics();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: Calendar Day Selector with Clear Option
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _selectedDate == null
                              ? 'Filter by Day: All'
                              : DateFormat(
                                  'MMMM d, yyyy',
                                ).format(_selectedDate!), // Fixed pattern token
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ).copyWith(left: 12),
                          alignment: Alignment.centerLeft,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _selectedMonth =
                                  'All'; // Avoid target query collisions
                              _selectedYear = 'All';
                              _fetchUnifiedAnalytics();
                            });
                          }
                        },
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Clear Day Filter',
                        style: IconButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.all(14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => setState(() {
                          _selectedDate = null;
                          _fetchUnifiedAnalytics();
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
            title: 'Present This Period',
            value: '$_presentCount',
            color: Colors.green.shade600,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Absent / Unreported',
            value: '$_absentCount',
            color: Colors.red.shade600,
            icon: Icons.remove_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unique System Enrollment Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatSubColumn(
                  'Total Students',
                  '$_totalEnrolled',
                  Colors.blueGrey,
                ),
                _buildStatSubColumn('Males', '$_males', Colors.blue),
                _buildStatSubColumn('Females', '$_females', Colors.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartVisualizer() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Live Active Headcount Ratio (Attendance Breakdown)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: (_presentCount == 0 && _absentCount == 0)
                  ? const Center(
                      child: Text(
                        "No tracking records logged for this time scope.",
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 35,
                        sections: [
                          PieChartSectionData(
                            color: Colors.green,
                            value: _presentCount.toDouble(),
                            title: 'P: $_presentCount',
                            radius: 45,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.red,
                            value: _absentCount.toDouble(),
                            title: 'A: $_absentCount',
                            radius: 45,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enrolled Student Distribution per Class Assignment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: _classMetrics.isEmpty
                  ? const Center(
                      child: Text(
                        "No class configurations match criteria.",
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            _classMetrics
                                .fold<int>(
                                  0,
                                  (max, e) => (e['classCount'] ?? 0) > max
                                      ? e['classCount']
                                      : max,
                                )
                                .toDouble() +
                            5,
                        barGroups: List.generate(_classMetrics.length, (index) {
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY:
                                    (_classMetrics[index]['classCount']
                                                as int? ??
                                            0)
                                        .toDouble(),
                                color: Colors.blueAccent.shade400,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                int i = val.toInt();
                                if (i >= 0 && i < _classMetrics.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      _classMetrics[i]['className']
                                              ?.toString() ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
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
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSubColumn(String label, String value, Color textTheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textTheme,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
