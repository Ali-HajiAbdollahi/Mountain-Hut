// MH-08 Cancel a booking — integration tests (My Bookings page + cancel dialog, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/hiker_portal/presentation/pages/my_bookings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeApi api;
  // Bookings are placed relative to the real clock, because the page uses DateTime.now()
  final now = DateTime.now();
  final nextWeek = DateTime(now.year, now.month, now.day + 7, 12);
  final tomorrow = now.add(const Duration(hours: 24));

  setUp(() {
    api = FakeApi()..bookings = [bookingJson(bID: 7, start: nextWeek)];
  });

  Future<void> open(WidgetTester tester) => pumpPage(tester, MyBookingsPage(api: api));

  Future<void> openCancelDialog(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('CANCEL BOOKING'));
    await tester.pumpAndSettle();
  }

  group('Cancel button on My Bookings', () {
    testWidgets('an upcoming booking can be cancelled', (tester) async {
      await open(tester);
      expect(find.text('CANCEL BOOKING'), findsOneWidget);
    });

    testWidgets('a booking less than 48 hours away is locked for changes but can still be cancelled',
        (tester) async {
      api.bookings = [bookingJson(start: tomorrow)];
      await open(tester);
      expect(find.text('MODIFICATION LOCKED'), findsOneWidget);
      expect(find.text('CANCEL BOOKING'), findsOneWidget);
    });

    testWidgets('a booking whose meal has already started can still be cancelled until it ends',
        (tester) async {
      api.bookings = [bookingJson(start: now.subtract(const Duration(minutes: 30)))];
      await open(tester);
      expect(find.text('CANCEL BOOKING'), findsOneWidget);
    });

    testWidgets('a booking whose slot has ended cannot be cancelled', (tester) async {
      api.bookings = [bookingJson(start: now.subtract(const Duration(hours: 3)))];
      await open(tester);
      expect(find.text('CANCEL BOOKING'), findsNothing);
    });
  });

  group('Cancel confirmation dialog', () {
    testWidgets('asks for confirmation, showing reference, date and that the tables will be released',
        (tester) async {
      await openCancelDialog(tester);
      expect(find.text('Cancel Reservation?'), findsOneWidget);
      expect(find.textContaining('REF MH-7'), findsOneWidget);
      expect(find.textContaining(slotTime(nextWeek)), findsOneWidget);
      expect(find.textContaining('assigned tables will be released'), findsOneWidget);
      expect(find.text('YES, CANCEL BOOKING'), findsOneWidget);
      expect(find.text('KEEP RESERVATION'), findsOneWidget);
      expect(api.called('cancelBooking'), isEmpty);
    });

    testWidgets('"Keep reservation" closes the dialog without cancelling', (tester) async {
      await openCancelDialog(tester);
      await tester.tap(find.text('KEEP RESERVATION'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Reservation?'), findsNothing);
      expect(api.called('cancelBooking'), isEmpty);
      expect(find.text('REF  #MH-7'), findsOneWidget);
    });

    testWidgets('confirming cancels that booking, confirms it and reloads the list', (tester) async {
      await openCancelDialog(tester);
      await tester.tap(find.text('YES, CANCEL BOOKING'));
      await tester.pumpAndSettle();

      expect(api.called('cancelBooking').single.args, {'id': 7});
      expect(find.text('Cancel Reservation?'), findsNothing);
      expect(find.text('Your booking was successfully cancelled.'), findsOneWidget);
      expect(api.called('myBookings'), hasLength(2));
      expect(find.text('REF  #MH-7'), findsNothing);
      expect(find.text('You have no upcoming reservations.'), findsOneWidget);
    });

    testWidgets('only the chosen booking is cancelled', (tester) async {
      api.bookings = [
        bookingJson(bID: 7, start: nextWeek),
        bookingJson(bID: 8, start: nextWeek.add(const Duration(days: 1))),
      ];
      await open(tester);
      // bookings are listed from the latest: MH-8 first, then MH-7
      await tester.tap(find.text('CANCEL BOOKING').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES, CANCEL BOOKING'));
      await tester.pumpAndSettle();

      expect(api.called('cancelBooking').single.args, {'id': 7});
      expect(find.text('REF  #MH-7'), findsNothing);
      expect(find.text('REF  #MH-8'), findsOneWidget);
    });

    testWidgets('a refusal from the server is shown in the dialog and the booking stays', (tester) async {
      api.cancelError = const ApiException(404, 'NOT_FOUND', 'Booking not found');
      await openCancelDialog(tester);
      await tester.tap(find.text('YES, CANCEL BOOKING'));
      await tester.pumpAndSettle();

      expect(find.text('Booking not found'), findsOneWidget);
      expect(find.text('Cancel Reservation?'), findsOneWidget);
      expect(find.text('Your booking was successfully cancelled.'), findsNothing);
      expect(api.called('myBookings'), hasLength(1));

      await tester.tap(find.text('KEEP RESERVATION'));
      await tester.pumpAndSettle();
      expect(find.text('REF  #MH-7'), findsOneWidget);
    });
  });
}
