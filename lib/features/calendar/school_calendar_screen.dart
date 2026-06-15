import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'repository/calendar_repository.dart';

class SchoolCalendarScreen extends StatefulWidget {
  const SchoolCalendarScreen({super.key});

  @override
  State<SchoolCalendarScreen> createState() => _SchoolCalendarScreenState();
}

class _SchoolCalendarScreenState extends State<SchoolCalendarScreen> {
  final _calendarRepo = CalendarRepository();

  // --- UPGRADED CALENDAR STATE ---
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  // NEW: State variable to control if the calendar is expanded (Month) or shrunk (Week)
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<String, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;

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

  // --- SELECTION HANDLERS ---

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

  // --- ADD EVENT MODAL ---
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
              title: Text(
                'Add Event: $dateLabel',
                style: const TextStyle(fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                        border: OutlineInputBorder(),
                      ),
                      items: types
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes/Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
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
                  child: const Text('Save Event'),
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
        return Colors.red.shade400;
      case 'Exam':
        return Colors.amber.shade700;
      case 'Deadline':
        return Colors.deepPurple.shade400;
      case 'Meeting':
        return Colors.blue.shade600;
      default:
        return Colors.teal;
    }
  }

  IconData _getIconForEventType(String type) {
    switch (type) {
      case 'Holiday':
        return Icons.celebration;
      case 'Exam':
        return Icons.text_snippet;
      case 'Deadline':
        return Icons.timer;
      case 'Meeting':
        return Icons.groups;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = _getEventsForRange();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('School Calendar'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- INTERACTIVE CALENDAR WIDGET ---
                Container(
                  color: Colors.white,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,

                    // NEW: Bind the dynamic format state
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
                      todayDecoration: BoxDecoration(
                        color: Colors.teal.shade200,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.teal.shade700,
                        shape: BoxShape.circle,
                      ),
                      rangeHighlightColor: Colors.teal.withOpacity(0.2),
                      rangeStartDecoration: BoxDecoration(
                        color: Colors.teal.shade700,
                        shape: BoxShape.circle,
                      ),
                      rangeEndDecoration: BoxDecoration(
                        color: Colors.teal.shade900,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible:
                          false, // Prevents layout jumping when shrinking
                    ),

                    // NEW: Update header to show the toggle button visually
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      formatButtonShowsNext: false,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      formatButtonTextStyle: TextStyle(
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // --- EVENTS LIST (Wrapped in Expanded to prevent overflow) ---
                Expanded(
                  child: displayEvents.isEmpty
                      ? Center(
                          child: Text(
                            'No events scheduled.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayEvents.length,
                          itemBuilder: (context, index) {
                            final event = displayEvents[index];
                            final color = _getColorForEventType(event['type']);

                            return Card(
                              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12.0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: color.withOpacity(0.5),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.2),
                                  child: Icon(
                                    _getIconForEventType(event['type']),
                                    color: color,
                                  ),
                                ),
                                title: Text(
                                  event['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        event['type'],
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteEvent(event['id']),
                                ),
                                isThreeLine:
                                    event['description'] != null &&
                                    event['description'].toString().isNotEmpty,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventModal,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }
}
