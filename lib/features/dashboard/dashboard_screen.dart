import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teacheros/features/demographics/demographic_screen.dart';
import '../attendance/repository/attendance_repository.dart';
import '../class_management/class_management_screen.dart';
import '../student_sis/student_list_screen.dart';
import '../attendance/attendance_records_screen.dart';
import '../grading/gradebook_screen.dart';
import '../assessment/assessment_builder_screen.dart';
import '../calendar/school_calendar_screen.dart';
import '../assignments/assignment_dashboard_screen.dart';
import '../toolkit/random_student_picker_screen.dart';
import '../settings/screens/backup_settings_screen.dart';

import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealLight = Color(0xFF5DCAA5);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);

  static const blueSurf = Color(0xFFE6F1FB);
  static const blueText = Color(0xFF185FA5);

  static const purpleSurf = Color(0xFFEEEDFE);
  static const purpleText = Color(0xFF534AB7);

  static const pinkSurf = Color(0xFFFBEAF0);
  static const pinkText = Color(0xFF993556);

  static const greenSurf = Color(0xFFEAF3DE);
  static const greenText = Color(0xFF3B6D11);

  static const amberSurf = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF854F0B);

  static const graySurf = Color(0xFFF1EFE8);
  static const grayText = Color(0xFF444441);

  static const redSurf = Color(0xFFFCEBEB);
  static const redText = Color(0xFFA32D2D);
  static const redBorder = Color(0xFFF09595);
}
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _attendanceRepo = AttendanceRepository();
  int _presentCount = 0;
  int _absentCount = 0;
  bool _loading = true;

  DateTime _currentDate = DateTime.now();

  // Weather
  String _weatherCondition = 'Loading...';
  String _temperature = '--°C';
  IconData _weatherIcon = Icons.cloud_queue_rounded;
  bool _weatherLoading = false;
  String _locationName = 'Detecting location…';

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchRealWeather();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchStats() async {
    final targetDateStr = _currentDate.toIso8601String().split('T')[0];
    try {
      final stats = await _attendanceRepo.getDailyAttendanceStats(
        targetDateStr,
      );
      if (mounted) {
        setState(() {
          _presentCount = stats['PRESENT'] ?? 0;
          _absentCount = stats['ABSENT'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard metrics: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRealWeather() async {
    if (_weatherLoading) return;
    setState(() => _weatherLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _setFallbackWeather();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse geocode
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final p = placemarks.first;
          setState(() {
            _locationName =
                '${p.locality ?? p.subAdministrativeArea ?? '?'}, ${p.country ?? ''}';
          });
        }
      } catch (_) {
        if (mounted) setState(() => _locationName = 'Location unavailable');
      }

      // Weather API
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,weathercode'
        '&temperature_unit=celsius',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['current']['temperature_2m'] as num;
        final code = data['current']['weathercode'] as int;
        if (mounted) {
          setState(() {
            _temperature = '${temp.toStringAsFixed(0)}°C';
            _weatherCondition = _wmoCodeToLabel(code);
            _weatherIcon = _wmoCodeToIcon(code);
            _weatherLoading = false;
          });
        }
      } else {
        _setFallbackWeather();
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      _setFallbackWeather();
    }
  }

  void _setFallbackWeather() {
    if (mounted) {
      setState(() {
        _temperature = '--°C';
        _weatherCondition = 'Unavailable';
        _weatherIcon = Icons.cloud_off_rounded;
        _weatherLoading = false;
      });
    }
  }

  String _wmoCodeToLabel(int c) {
    if (c == 0) return 'Clear Sky';
    if (c <= 2) return 'Partly Cloudy';
    if (c == 3) return 'Overcast';
    if (c <= 49) return 'Foggy';
    if (c <= 59) return 'Drizzle';
    if (c <= 69) return 'Raining';
    if (c <= 79) return 'Snowing';
    if (c <= 82) return 'Rain Showers';
    if (c <= 84) return 'Hail Showers';
    if (c <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData _wmoCodeToIcon(int c) {
    if (c == 0) return Icons.wb_sunny_rounded;
    if (c <= 2) return Icons.wb_cloudy_rounded;
    if (c == 3) return Icons.cloud_rounded;
    if (c <= 49) return Icons.foggy;
    if (c <= 69) return Icons.grain_rounded;
    if (c <= 79) return Icons.ac_unit_rounded;
    if (c <= 82) return Icons.umbrella_rounded;
    if (c <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  // ── Date Picker ────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _Brand.teal,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _currentDate) {
      setState(() {
        _currentDate = picked;
        _loading = true;
      });
      _fetchStats();
    }
  }

  // ── Quick Access Items ─────────────────────────────────────────────────────

  List<_QAItem> get _quickAccessItems => [
    _QAItem(
      'Class Mgmt.',
      'Sections',
      Icons.co_present_rounded,
      _Brand.amberSurf,
      _Brand.amberText,
      const ClassManagementScreen(),
    ),
    _QAItem(
      'Students',
      'SIS records',
      Icons.people_alt_rounded,
      _Brand.blueSurf,
      _Brand.blueText,
      const StudentListScreen(),
    ),
    _QAItem(
      'Attendance',
      'Daily logs',
      Icons.check_circle_outline_rounded,
      _Brand.tealSurf,
      _Brand.tealMid,
      const AttendanceRecordsScreen(),
    ),
    _QAItem(
      'Gradebook',
      'Scores',
      Icons.menu_book_rounded,
      _Brand.purpleSurf,
      _Brand.purpleText,
      const GradebookScreen(),
    ),
    _QAItem(
      'Assessments',
      'Builder',
      Icons.assignment_rounded,
      _Brand.pinkSurf,
      _Brand.pinkText,
      const AssessmentBuilderScreen(),
    ),
    _QAItem(
      'Assignments',
      'Hub',
      Icons.assignment_turned_in_rounded,
      _Brand.greenSurf,
      _Brand.greenText,
      const AssignmentHubScreen(),
    ),
    _QAItem(
      'Calendar',
      'Events',
      Icons.calendar_month_rounded,
      _Brand.blueSurf,
      _Brand.blueText,
      const SchoolCalendarScreen(),
    ),
    _QAItem(
      'Random Picker',
      'Students',
      Icons.shuffle_rounded,
      _Brand.tealSurf,
      _Brand.tealMid,
      const RandomStudentPickerScreen(),
    ),
    _QAItem(
      'Demographics',
      'Overview',
      Icons.pie_chart_outline_rounded,
      _Brand.purpleSurf,
      _Brand.purpleText,
      const StudentDemographicsScreen(),
    ),
    _QAItem(
      'Settings',
      'Backup',
      Icons.settings_outlined,
      _Brand.graySurf,
      _Brand.grayText,
      const BackupSettingsScreen(),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _Brand.teal)),
      );
    }

    final int total = _presentCount + _absentCount;
    final double percentage = total > 0 ? (_presentCount / total * 100) : 0.0;
    final String dateLabel = DateFormat('MMM d, yyyy').format(_currentDate);
    final String weekday = DateFormat('EEEE').format(_currentDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _currentDate = DateTime.now());
          _fetchRealWeather();
          await _fetchStats();
        },
        color: _Brand.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(context, dateLabel, weekday),
              const SizedBox(height: 16),
              _buildWeatherCard(),
              const SizedBox(height: 14),
              _buildAttendanceMetricCard(total, percentage),
              const SizedBox(height: 24),
              _buildSectionLabel('Quick Access'),
              const SizedBox(height: 12),
              _buildQuickAccessList(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo + name
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _Brand.tealMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icon/teachOs_logo.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.gavel_rounded,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'teachOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 19,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            // Powered by
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'powered by',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black38,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'XIENTECH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _Brand.tealMid,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Date Header ────────────────────────────────────────────────────────────

  Widget _buildDateHeader(
    BuildContext context,
    String dateLabel,
    String weekday,
  ) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$dateLabel · $weekday',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: _Brand.teal,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(Icons.touch_app_rounded, size: 12, color: _Brand.teal),
              SizedBox(width: 4),
              Text(
                'Tap to change date',
                style: TextStyle(fontSize: 11, color: _Brand.teal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Weather Card ───────────────────────────────────────────────────────────

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _Brand.tealSurf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Brand.tealBorder, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _weatherLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _Brand.tealMid,
                      ),
                    )
                  : Text(
                      _temperature,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: _Brand.tealDark,
                      ),
                    ),
              const SizedBox(height: 3),
              Text(
                _weatherCondition,
                style: const TextStyle(fontSize: 13, color: _Brand.tealMid),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: _Brand.teal,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _locationName,
                    style: const TextStyle(fontSize: 11, color: _Brand.teal),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFC8F0E3),
              shape: BoxShape.circle,
            ),
            child: Icon(_weatherIcon, size: 28, color: _Brand.tealMid),
          ),
        ],
      ),
    );
  }

  // ── Attendance Metric Card ─────────────────────────────────────────────────

  Widget _buildAttendanceMetricCard(int total, double percentage) {
    final bool hasData = total > 0;
    final String dateLabel = DateFormat('MMM d').format(_currentDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance — $dateLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Brand.tealSurf,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: _Brand.tealMid,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Big number
          Text(
            hasData ? '${percentage.toStringAsFixed(1)}%' : 'No records',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasData
                ? '$_presentCount present out of $total tracked'
                : 'No attendance logs for this date.',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),

          if (hasData) ...[
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _presentCount / total,
                minHeight: 5,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(_Brand.teal),
              ),
            ),
            const SizedBox(height: 12),

            // Chips
            Row(
              children: [
                _statusChip(
                  '$_presentCount Present',
                  _Brand.tealSurf,
                  _Brand.tealMid,
                  _Brand.tealLight,
                ),
                const SizedBox(width: 8),
                _statusChip(
                  '$_absentCount Absent',
                  _Brand.redSurf,
                  _Brand.redText,
                  _Brand.redBorder,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color bg, Color text, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: text,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Quick Access List ──────────────────────────────────────────────────────

  Widget _buildQuickAccessList(BuildContext context) {
    final items = _quickAccessItems;
    return Column(
      children: [
        for (int i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: Row(
              children: [
                Expanded(child: _buildQAItem(context, items[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < items.length
                      ? _buildQAItem(context, items[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQAItem(BuildContext context, _QAItem item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.screen),
        ).then((_) => _fetchStats());
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // Tightened horizontal padding from 14 to 10 to yield room to text container
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 18),
            ),
            // Tightened column gap spacing from 12 to 8
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guard long words with a clean scaledown layout to prevent trailing breaks
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ── Data model ────────────────────────────────────────────────────────────────

class _QAItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget screen;

  const _QAItem(
    this.title,
    this.subtitle,
    this.icon,
    this.iconBg,
    this.iconColor,
    this.screen,
  );
}
