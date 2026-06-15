import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/database_service.dart';

class CalendarRepository {
  final _dbService = DatabaseService.instance;

  /// Fetch all events and group them by Date string (YYYY-MM-DD)
  Future<Map<String, List<Map<String, dynamic>>>> getGroupedEvents() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> rawEvents = await db.query(
      'calendar_events',
      orderBy: 'event_date ASC',
    );

    final Map<String, List<Map<String, dynamic>>> groupedEvents = {};

    for (var event in rawEvents) {
      final dateStr = event['event_date'] as String;
      if (!groupedEvents.containsKey(dateStr)) {
        groupedEvents[dateStr] = [];
      }
      groupedEvents[dateStr]!.add(event);
    }

    return groupedEvents;
  }

  /// Add a new event to the calendar
  Future<void> addEvent({
    required String id,
    required String title,
    required String type,
    required String eventDate,
    required String description,
  }) async {
    final db = await _dbService.database;
    await db.insert('calendar_events', {
      'id': id,
      'title': title,
      'type': type,
      'event_date': eventDate,
      'description': description,
    });
  }

  /// Delete an event
  Future<void> deleteEvent(String id) async {
    final db = await _dbService.database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
  }
}
