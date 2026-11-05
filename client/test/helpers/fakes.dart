// Test doubles shared by the frontend tests: no backend and no network.
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/auth/domain/repositories/auth_repository.dart';
import 'package:client/features/booking/domain/entities/booking_allocation.dart';
import 'package:client/features/booking/domain/repositories/booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call as "method" plus its arguments.
class Call {
  Call(this.method, [this.args = const {}]);

  final String method;
  final Map<String, Object?> args;
}

/// Fake MountainHutApi: each method returns the configured answer, or throws
/// the configured ApiException. Methods not overridden throw UnimplementedError.
class FakeApi extends Fake implements MountainHutApi {
  final calls = <Call>[];

  Map<String, dynamic>? user; // null = no session (401)
  List<Map<String, dynamic>> slots = [];
  ApiException? slotsError;
  Map<String, dynamic> availability = {'available': false, 'allocation': []};
  ApiException? availabilityError;
  Map<String, dynamic> bookResponse = {};
  ApiException? bookError;
  List<Map<String, dynamic>> bookings = [];
  ApiException? bookingsError;
  ApiException? updateError;

  Iterable<Call> called(String method) => calls.where((c) => c.method == method);

  @override
  Future<Map<String, dynamic>> currentUser() async {
    calls.add(Call('currentUser'));
    if (user == null) {
      throw const ApiException(401, 'UNAUTHENTICATED', 'Login required');
    }
    return user!;
  }

  @override
  Future<List<Map<String, dynamic>>> listSlots(String date) async {
    calls.add(Call('listSlots', {'date': date}));
    if (slotsError != null) throw slotsError!;
    return slots;
  }

  @override
  Future<Map<String, dynamic>> checkAvailability({
    required String date,
    required String time,
    required int partySize,
  }) async {
    calls.add(Call('checkAvailability', {'date': date, 'time': time, 'partySize': partySize}));
    if (availabilityError != null) throw availabilityError!;
    return availability;
  }

  @override
  Future<Map<String, dynamic>> book({
    required int slotId,
    required int people,
    List<Map<String, dynamic>> requirements = const [],
  }) async {
    calls.add(Call('book', {'slotId': slotId, 'people': people, 'requirements': requirements}));
    if (bookError != null) throw bookError!;
    return bookResponse;
  }

  @override
  Future<List<Map<String, dynamic>>> myBookings() async {
    calls.add(Call('myBookings'));
    if (bookingsError != null) throw bookingsError!;
    return [...bookings];
  }

  @override
  Future<Map<String, dynamic>> updateBooking(
    int id, {
    int? slotId,
    int? people,
    List<Map<String, dynamic>>? requirements,
  }) async {
    calls.add(Call('updateBooking',
        {'id': id, 'slotId': slotId, 'people': people, 'requirements': requirements}));
    if (updateError != null) throw updateError!;
    return {'booking': {}};
  }
}

/// Booking repository that records what the page sends.
class FakeBookingRepository implements BookingRepository {
  final requests = <Map<String, Object?>>[];
  Map<String, dynamic> response = {};
  ApiException? error;

  @override
  Future<Map<String, dynamic>> createBooking({
    required int slotId,
    required int partySize,
    required List<Map<String, dynamic>> requirements,
  }) async {
    requests.add({'slotId': slotId, 'partySize': partySize, 'requirements': requirements});
    if (error != null) throw error!;
    return response;
  }
}

class FakeAuthRepository extends Fake implements AuthRepository {}

const allocation = BookingAllocation(
  date: '12/01/2026',
  slotId: 3,
  startTime: '12:00',
  endTime: '13:00',
  partySize: 4,
  seasonLabel: 'Winter Peak',
  seatingLabel: 'Lunch Seating',
  tablesLabel: 'Tables 2',
);

/// A booking as returned by the backend (GET /api/bookings).
Map<String, dynamic> bookingJson({
  int bID = 7,
  int tsID = 3,
  int people = 4,
  required DateTime start,
  List<Map<String, dynamic>> requirements = const [],
  List<Map<String, dynamic>> tables = const [{'table_no': 2, 'seats': 4}],
}) => {
  'bID': bID,
  'tsID': tsID,
  'reference': 'MH-$bID',
  'contact_name': 'Marco Bianchi',
  'n_people': people,
  'start_time': slotTime(start),
  'end_time': slotTime(start.add(const Duration(hours: 1))),
  'created_at': '2026-11-01 10:00:00',
  'tables': tables,
  'requirements': requirements,
};

/// 'YYYY-MM-DD HH:MM', the format used by the backend.
String slotTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// Renders [page] on a tall screen so that whole pages fit without scrolling.
Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}
