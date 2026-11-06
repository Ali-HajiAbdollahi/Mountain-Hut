// MH-01 Book a table — integration tests (pages + navigation + repository, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/auth/presentation/pages/auth_screen.dart';
import 'package:client/features/booking/presentation/pages/booking_page.dart';
import 'package:client/features/booking/presentation/pages/booking_success_page.dart';
import 'package:client/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('BookingPage', () {
    late FakeApi api;
    late FakeBookingRepository repository;

    setUp(() {
      api = FakeApi();
      repository = FakeBookingRepository()
        ..response = {
          'booking': {'bID': 12, 'reference': 'MH-12', 'contact_name': 'Marco Bianchi', 'tables': [], 'requirements': []},
          'notification': {'status': 'accepted'},
        };
    });

    Future<void> open(WidgetTester tester) =>
        pumpPage(tester, BookingPage(allocation: allocation, repository: repository, api: api));

    testWidgets('shows date, time slot and party size chosen in the availability check', (tester) async {
      await open(tester);
      expect(find.text('12/01/2026'), findsOneWidget);
      expect(find.text('12:00–13:00'), findsOneWidget);
      expect(find.text('4 Guests'), findsOneWidget);
    });

    testWidgets('confirming books the selected slot and opens the confirmation page', (tester) async {
      await open(tester);
      await tester.tap(find.text('CONFIRM RESERVATION'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {'slotId': 3, 'partySize': 4, 'requirements': []});
      expect(find.byType(BookingSuccessPage), findsOneWidget);
      expect(find.text('Your table is reserved!'), findsOneWidget);
      expect(find.text('#MH-12'), findsOneWidget);
    });

    testWidgets('a full slot (409) shows the server message and stays on the page', (tester) async {
      repository.error = const ApiException(409, 'CONFLICT', 'Not enough free seats');
      await open(tester);
      await tester.tap(find.text('CONFIRM RESERVATION'));
      await tester.pumpAndSettle();

      expect(find.text('Not enough free seats'), findsOneWidget);
      expect(find.byType(BookingSuccessPage), findsNothing);
    });

    testWidgets('the 2-hour closing rule (409) is reported to the hiker', (tester) async {
      repository.error = const ApiException(409, 'CONFLICT', 'Bookings close two hours before the slot');
      await open(tester);
      await tester.tap(find.text('CONFIRM RESERVATION'));
      await tester.pumpAndSettle();

      expect(find.text('Bookings close two hours before the slot'), findsOneWidget);
    });
  });

  group('From availability check to booking', () {
    late FakeApi api;

    setUp(() {
      api = FakeApi()
        ..slots = [
          {'tsID': 3, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:00', 'tables': []},
        ]
        ..availability = {
          'available': true,
          'partySize': 6,
          'slot': {'tsID': 3, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:00'},
          'allocation': [{'table_no': 4, 'seats': 6}],
        };
    });

    Future<void> checkAndProceed(WidgetTester tester) async {
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));
      await tester.tap(find.text('Check Availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed to Reservation'));
      await tester.pumpAndSettle();
    }

    testWidgets('a visitor without an account is asked to sign in or register', (tester) async {
      await checkAndProceed(tester);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(BookingPage), findsNothing);
    });

    testWidgets('a signed-in hiker goes to the booking page with the chosen slot and party size', (tester) async {
      api.user = {'uID': 1, 'role': 'hiker'};
      await checkAndProceed(tester);

      final page = tester.widget<BookingPage>(find.byType(BookingPage));
      expect(page.allocation.slotId, 3);
      expect(page.allocation.partySize, 6);
      expect(page.allocation.tablesLabel, 'Tables 4');
    });

    testWidgets('a signed-in employee is not treated as a hiker', (tester) async {
      api.user = {'uID': 9, 'role': 'employee'};
      await checkAndProceed(tester);
      expect(find.byType(BookingPage), findsNothing);
    });
  });
}
