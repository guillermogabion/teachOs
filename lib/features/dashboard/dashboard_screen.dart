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
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

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
  int _bottomNavIndex = 0;

  // Weather & Calendar States
  DateTime _currentDate = DateTime.now();
  String _weatherCondition = 'Loading...';
  String _temperature = '--°C';
  IconData _weatherIcon = Icons.cloud_queue_rounded;
  bool _weatherLoading = false;

  String _locationName = 'Detecting location...';

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchRealWeather();
  }

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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _currentDate) {
      setState(() {
        _currentDate = picked;
        _loading = true;
      });
      _fetchRealWeather();
      _fetchStats();
    }
  }

  Future<void> _fetchRealWeather() async {
    if (_weatherLoading) return;
    setState(() => _weatherLoading = true);

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          // Combines City and Country
          _locationName =
              '${place.locality ?? place.subAdministrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() => _locationName = 'Location unavailable');
    }

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

  String _wmoCodeToLabel(int code) {
    if (code == 0) return 'Clear Sky';
    if (code <= 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code <= 49) return 'Foggy';
    if (code <= 59) return 'Drizzling';
    if (code <= 69) return 'Raining';
    if (code <= 79) return 'Snowing';
    if (code <= 82) return 'Rain Showers';
    if (code <= 84) return 'Hail Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData _wmoCodeToIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code <= 49) return Icons.foggy;
    if (code <= 69) return Icons.grain_rounded;
    if (code <= 79) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.umbrella_rounded;
    if (code <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  // Define Quick Access Menu Items
  List<Map<String, dynamic>> _getQuickAccessItems() {
    return [
      {
        'title': 'Students (SiS)',
        'icon': Icons.people_alt_rounded,
        'color': Colors.blue.shade400,
        'screen': const StudentListScreen(),
      },
      {
        'title': 'Attendance',
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.green.shade400,
        'screen': const AttendanceRecordsScreen(),
      },
      {
        'title': 'Gradebook',
        'icon': Icons.menu_book_rounded,
        'color': Colors.purple.shade300,
        'screen': const GradebookScreen(),
      },
      {
        'title': 'Assessments',
        'icon': Icons.assignment_rounded,
        'color': Colors.pink.shade300,
        'screen': const AssessmentBuilderScreen(),
      },
      {
        'title': 'Assignments',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.green.shade600,
        'screen':
            const AssignmentHubScreen(), // Assuming this exists based on imports
      },
      {
        'title': 'Calendar',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.blueAccent.shade200,
        'screen': const SchoolCalendarScreen(),
      },
      {
        'title': 'Class Mgmt.',
        'icon': Icons.co_present_rounded,
        'color': Colors.blue.shade700,
        'screen': const ClassManagementScreen(),
      },
      {
        'title': 'Random Picker',
        'icon': Icons
            .content_paste_rounded, // Replaced casino icon to match image vibe
        'color': Colors.orange.shade400,
        'screen': const RandomStudentPickerScreen(),
      },
      {
        'title': 'Demographics',
        'icon': Icons.pie_chart_outline_rounded,
        'color': Colors.teal.shade400,
        'screen': const StudentDemographicsScreen(),
      },
      {
        'title': 'Backup & Settings',
        'icon': Icons.settings_outlined,
        'color': Colors.grey.shade700,
        'screen': const BackupSettingsScreen(),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String localizedDateStr = DateFormat('MMM d, yyyy').format(_currentDate);
    String weekdayStr = DateFormat('EEEE').format(_currentDate);
    int total = _presentCount + _absentCount;
    double percentage = total > 0 ? (_presentCount / total * 100) : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icon/teachOs_logo.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.gavel_rounded,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'teachOS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'powered by',
                    style: TextStyle(
                      fontSize: 8,
                      color: Color.fromARGB(255, 9, 59, 54),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    'XIENTECH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 9, 59, 54),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _currentDate = DateTime.now());
          _fetchRealWeather();
          await _fetchStats();
        },
        color: Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$localizedDateStr • $weekdayStr',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weather Card
              _buildWeatherCard(),
              const SizedBox(height: 24),

              // Attendance Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Attendance",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AttendanceRecordsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "View all",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Attendance Cards (Present / Absent)
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Date Attendance Metric',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total > 0
                                  ? '${percentage.toStringAsFixed(1)}%'
                                  : 'No Logs Registered',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total > 0
                                  ? '$_presentCount present out of $total tracked records.'
                                  : 'No registry markers found for this target timeline split.',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.analytics_outlined,
                        color: Colors.teal,
                        size: 56,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Access Header
              const Text(
                "Quick Access",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Responsive Quick Access Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  // Adjust columns based on available width
                  int crossAxisCount = 3; // Mobile default
                  if (constraints.maxWidth > 600) crossAxisCount = 4; // Tablet
                  if (constraints.maxWidth > 900)
                    crossAxisCount = 6; // Small Desktop
                  if (constraints.maxWidth > 1200)
                    crossAxisCount = 8; // Large Desktop

                  final items = _getQuickAccessItems();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          0.9, // Adjust ratio for square/rectangle card
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildGridItem(
                        title: item['title'],
                        icon: item['icon'],
                        color: item['color'],
                        onTap: () {
                          if (item['screen'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => item['screen'],
                              ),
                            ).then((_) => _fetchStats());
                          }
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar Implementation matching the image
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _bottomNavIndex,
      //   onTap: (index) {
      //     setState(() {
      //       _bottomNavIndex = index;
      //     });
      //   },
      //   selectedItemColor: Colors.teal.shade700,
      //   unselectedItemColor: Colors.grey.shade500,
      //   showSelectedLabels: true,
      //   showUnselectedLabels: true,
      //   selectedLabelStyle: const TextStyle(
      //     fontWeight: FontWeight.bold,
      //     fontSize: 12,
      //   ),
      //   unselectedLabelStyle: const TextStyle(
      //     fontWeight: FontWeight.normal,
      //     fontSize: 12,
      //   ),
      //   type: BottomNavigationBarType.fixed,
      //   backgroundColor: Colors.white,
      //   elevation: 8,
      //   items: [
      //     BottomNavigationBarItem(
      //       icon: Container(
      //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      //         decoration: BoxDecoration(
      //           color: _bottomNavIndex == 0
      //               ? Colors.teal.shade600
      //               : Colors.transparent,
      //           borderRadius: BorderRadius.circular(20),
      //         ),
      //         child: Icon(
      //           Icons.home_rounded,
      //           color: _bottomNavIndex == 0
      //               ? Colors.white
      //               : Colors.grey.shade500,
      //         ),
      //       ),
      //       label: 'Dashboard',
      //     ),
      //     const BottomNavigationBarItem(
      //       icon: Padding(
      //         padding: EdgeInsets.symmetric(vertical: 6.0),
      //         child: Icon(Icons.calendar_today_rounded),
      //       ),
      //       label: 'Calendar',
      //     ),
      //     const BottomNavigationBarItem(
      //       icon: Padding(
      //         padding: EdgeInsets.symmetric(vertical: 6.0),
      //         child: Icon(Icons.more_horiz_rounded),
      //       ),
      //       label: 'More',
      //     ),
      //   ],
      // ),
    );
  }

  // --- UI Builder Methods ---

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _weatherLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _temperature,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
              const SizedBox(height: 4),
              Text(
                _weatherCondition,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _locationName, // Replace "Manila, Philippines" with this variable
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          // Weather Icon Area
          Icon(_weatherIcon, size: 64, color: Colors.orange.shade400),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'Students',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
