import 'package:flutter/foundation.dart';

class ApiEndpoints {
  const ApiEndpoints._();

  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001/api';
    }

    return 'http://localhost:3001/api';
  }

  static const String health = '/health';
  static const String users = '/users';
  static const String sessions = '/sessions';
  static const String currentSession = '/sessions/current';
  static const String timeslots = '/timeslots';
  static const String bookings = '/bookings';
  static const String availability = '/availability';
  static const String repeatWeek = '$timeslots/repeat-week';

  static String timeslot(int id) => '$timeslots/$id';
  static String slotTables(int id) => '$timeslots/$id/tables';
  static String slotMenu(int id) => '$timeslots/$id/menu';
  static String booking(int id) => '$bookings/$id';
  static String confirmation(int id) => '$bookings/$id/confirmation';
  static const String staffHikers = '/staff/hikers';
  static const String staffBookings = '/staff/bookings';
}
