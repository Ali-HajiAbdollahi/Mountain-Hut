class ApiEndpoints {
  const ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  static const String health = '/health';
  static const String users = '/users';
  static const String sessions = '/sessions';
  static const String currentSession = '/sessions/current';
  static const String timeslots = '/timeslots';
  static const String bookings = '/bookings';
  static const String availability = '/availability';

  static String timeslot(int id) => '$timeslots/$id';
  static String slotTables(int id) => '$timeslots/$id/tables';
  static String booking(int id) => '$bookings/$id';
  static String confirmation(int id) => '$bookings/$id/confirmation';
}