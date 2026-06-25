import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'repository/calendar_repository.dart';

// ─── Unified Brand Palette ───────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
  static const bgSurface = Color(0xFFF9FAFB);
  static const amberWarning = Color(0xFFD97706);
  static const amberSurf = Color(0xFFFEF3C7);
  static const redText = Color(0xFFDC2626);
  static const redSurf = Color(0xFFFEE2E2);
  static const blueAccent = Color(0xFF2563EB);
  static const blueSurf = Color(0xFFDBEAFE);
}

// ─── Standardized Input Decoration Helper ────────────────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    suffix: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
    ),
  );
}

// ============================================================================
// CORE SCREEN: SCHOOL CALENDAR (HIGH FIDELITY REFRACTOR)
// ============================================================================
class SchoolCalendarScreen extends StatefulWidget {
  const SchoolCalendarScreen({super.key});

  @override
  State<SchoolCalendarScreen> createState() => _SchoolCalendarScreenState();
}

class _SchoolCalendarScreenState extends State<SchoolCalendarScreen>
    with RestorationMixin<SchoolCalendarScreen> {
  final RestorableString _calendarScreen = RestorableString('');
  final _calendarRepo = CalendarRepository();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<String, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;

  @override
  String? get restorationId => 'school_calendar_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_calendarScreen, 'school_calendar_screen');
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final data = await _calendarRepo.getGroupedEvents();
    setState(() {
      _events = data;
      _isLoading = false;
    });
  }

  String _dateToStr(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[_dateToStr(day)] ?? [];
  }

  List<Map<String, dynamic>> _getEventsForRange() {
    if (_rangeStart != null && _rangeEnd != null) {
      final days = _getDaysInRange(_rangeStart!, _rangeEnd!);
      List<Map<String, dynamic>> rangeEvents = [];
      for (var day in days) {
        rangeEvents.addAll(_getEventsForDay(day));
      }
      final uniqueEvents = {
        for (var e in rangeEvents) e['id']: e,
      }.values.toList();
      return uniqueEvents;
    }
    return _getEventsForDay(_selectedDay ?? _focusedDay);
  }

  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      days.add(start.add(Duration(days: i)));
    }
    return days;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null;
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });
  }

  Future<void> _showAddEventModal() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'Meeting';
    final types = ['Holiday', 'Exam', 'Meeting', 'Deadline'];

    final isRange = _rangeStart != null && _rangeEnd != null;
    final dateLabel = isRange
        ? '${DateFormat('MMM d').format(_rangeStart!)} - ${DateFormat('MMM d').format(_rangeEnd!)}'
        : DateFormat('MMM d').format(_selectedDay ?? _focusedDay);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add Event: $dateLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _Brand.charcoal,
                  fontSize: 18,
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  // Optional: set a max height if you want to prevent it from taking the whole screen
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _buildInputDecoration(
                        labelText: 'Event Title',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Brand.charcoal,
                      ),
                      decoration: _buildInputDecoration(
                        labelText: 'Event Type',
                      ),
                      items: types
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _buildInputDecoration(
                        labelText: 'Notes/Description',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _Brand.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Brand.tealDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;

                    final eventId = const Uuid().v4();

                    if (isRange) {
                      final days = _getDaysInRange(_rangeStart!, _rangeEnd!);
                      for (var day in days) {
                        await _calendarRepo.addEvent(
                          id: '${eventId}_${_dateToStr(day)}',
                          title: titleCtrl.text,
                          type: selectedType,
                          eventDate: _dateToStr(day),
                          description: descCtrl.text,
                        );
                      }
                    } else {
                      await _calendarRepo.addEvent(
                        id: eventId,
                        title: titleCtrl.text,
                        type: selectedType,
                        eventDate: _dateToStr(_selectedDay ?? _focusedDay),
                        description: descCtrl.text,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadEvents();
                    }
                  },
                  child: const Text(
                    'Save Event',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(String id) async {
    await _calendarRepo.deleteEvent(id);
    _loadEvents();
  }

  Color _getColorForEventType(String type) {
    switch (type) {
      case 'Holiday':
        return _Brand.redText;
      case 'Exam':
        return _Brand.amberWarning;
      case 'Deadline':
        return const Color(
          0xFF7C3AED,
        ); // Styled deep purple matching project context
      case 'Meeting':
        return _Brand.blueAccent;
      default:
        return _Brand.teal;
    }
  }

  Color _getSurfaceColorForEventType(String type) {
    switch (type) {
      case 'Holiday':
        return _Brand.redSurf;
      case 'Exam':
        return _Brand.amberSurf;
      case 'Deadline':
        return const Color(0xFFF3E8FF);
      case 'Meeting':
        return _Brand.blueSurf;
      default:
        return _Brand.tealSurf;
    }
  }

  IconData _getIconForEventType(String type) {
    switch (type) {
      case 'Holiday':
        return Icons.celebration_rounded;
      case 'Exam':
        return Icons.text_snippet_rounded;
      case 'Deadline':
        return Icons.timer_rounded;
      case 'Meeting':
        return Icons.groups_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = _getEventsForRange();

    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: AppBar(
        title: const Text(
          'School Calendar',
          style: TextStyle(fontWeight: FontWeight.w700, color: _Brand.charcoal),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : Column(
              children: [
                // Container wrapper for layout structural integrity
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    rangeStartDay: _rangeStart,
                    rangeEndDay: _rangeEnd,
                    rangeSelectionMode: _rangeSelectionMode,
                    eventLoader: _getEventsForDay,
                    onDaySelected: _onDaySelected,
                    onRangeSelected: _onRangeSelected,
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: const TextStyle(
                        color: _Brand.charcoal,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      weekendTextStyle: const TextStyle(
                        color: _Brand.mutedText,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      todayTextStyle: const TextStyle(
                        color: _Brand.tealMid,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      todayDecoration: const BoxDecoration(
                        color: _Brand.tealSurf,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: _Brand.tealDark,
                        shape: BoxShape.circle,
                      ),
                      rangeHighlightColor: _Brand.tealSurf.withOpacity(0.5),
                      rangeStartTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      rangeStartDecoration: const BoxDecoration(
                        color: _Brand.tealDark,
                        shape: BoxShape.circle,
                      ),
                      rangeEndTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      rangeEndDecoration: const BoxDecoration(
                        color: _Brand.tealMid,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markerDecoration: const BoxDecoration(
                        color: _Brand.teal,
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      formatButtonShowsNext: false,
                      titleCentered: true,
                      titleTextStyle: const TextStyle(
                        color: _Brand.charcoal,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      leftChevronIcon: const Icon(
                        Icons.chevron_left_rounded,
                        color: _Brand.tealMid,
                      ),
                      rightChevronIcon: const Icon(
                        Icons.chevron_right_rounded,
                        color: _Brand.tealMid,
                      ),
                      formatButtonDecoration: BoxDecoration(
                        color: _Brand.tealSurf,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: _Brand.teal.withOpacity(0.15),
                        ),
                      ),
                      formatButtonTextStyle: const TextStyle(
                        color: _Brand.tealDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),

                // Core Tasks Engine Pipeline Viewport
                Expanded(
                  child: displayEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No events scheduled for this block.',
                                style: TextStyle(
                                  color: _Brand.mutedText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(18),
                          itemCount: displayEvents.length,
                          itemBuilder: (context, index) {
                            final event = displayEvents[index];
                            final color = _getColorForEventType(event['type']);
                            final surfaceColor = _getSurfaceColorForEventType(
                              event['type'],
                            );

                            return Container(
                              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.shade100,
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getIconForEventType(event['type']),
                                    color: color,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  event['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _Brand.charcoal,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          event['type'],
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (event['description'] != null &&
                                          event['description']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          event['description'],
                                          style: const TextStyle(
                                            color: _Brand.mutedText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventModal,
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Event',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
