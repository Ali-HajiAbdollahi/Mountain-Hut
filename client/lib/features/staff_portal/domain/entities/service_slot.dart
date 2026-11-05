import 'table_draft.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `2026-11-06`, the format expected by the API.
String formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `Friday, 6 Nov 2026`
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

class ServiceSlot {
  const ServiceSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.freeSeats,
    required this.tables,
  });

  factory ServiceSlot.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'];
    return ServiceSlot(
      id: (json['tsID'] as num).toInt(),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      freeSeats: (json['free_seats'] as num?)?.toInt() ?? 0,
      tables: rawTables is List
          ? rawTables
              .whereType<Map<String, dynamic>>()
              .map(TableDraft.fromJson)
              .toList()
          : const [],
    );
  }

  final int id;

  /// `YYYY-MM-DD HH:MM` (Europe/Rome)
  final String startTime;
  final String endTime;
  final int capacity;
  final int freeSeats;
  final List<TableDraft> tables;

  bool get hasLayout => tables.isNotEmpty;

  String get startLabel => startTime.substring(11, 16);
  String get endLabel => endTime.substring(11, 16);

  int get durationMinutes {
    final start = DateTime.parse(startTime.replaceFirst(' ', 'T'));
    final end = DateTime.parse(endTime.replaceFirst(' ', 'T'));
    return end.difference(start).inMinutes;
  }
}