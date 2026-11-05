// MH-03 Receive confirmation — integration tests (confirmation page, fake API)
import 'package:client/features/booking/presentation/pages/booking_page.dart';
import 'package:client/features/booking/presentation/pages/booking_success_page.dart';
import 'package:client/features/hiker_portal/presentation/pages/my_bookings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const emailText = 'A confirmation email has been sent';

void main() {
  late FakeApi api;

  final booking = {
    'bID': 12,
    'reference': 'MH-12',
    'contact_name': 'Marco Bianchi',
    'tables': [{'table_no': 2, 'seats': 2}, {'table_no': 1, 'seats': 2}],
    'requirements': [],
  };

  setUp(() => api = FakeApi());

  Future<void> openSuccess(WidgetTester tester, {bool notificationSent = true}) => pumpPage(
        tester,
        BookingSuccessPage(api: api, booking: booking, allocation: allocation, notificationSent: notificationSent),
      );

  group('BookingSuccessPage', () {
    testWidgets('shows reference, hiker name, date, slot, party size and tables', (tester) async {
      await openSuccess(tester);

      expect(find.text('#MH-12'), findsOneWidget);
      expect(find.text('Marco Bianchi'), findsOneWidget);
      expect(find.text('12/01/2026'), findsOneWidget);
      expect(find.text('Lunch 12:00 – 13:00'), findsOneWidget);
      expect(find.text('4 Guests'), findsOneWidget);
      expect(find.text('Tables 1 & 2'), findsOneWidget);
    });

    testWidgets('says when there are no dietary requirements', (tester) async {
      await openSuccess(tester);
      expect(find.text('No dietary requirements specified.'), findsOneWidget);
    });

    testWidgets('shows the email notice when the email was sent', (tester) async {
      await openSuccess(tester);
      expect(find.textContaining(emailText), findsOneWidget);
    });

    testWidgets('hides the email notice when the email was not sent', (tester) async {
      await openSuccess(tester, notificationSent: false);
      expect(find.textContaining(emailText), findsNothing);
    });

    testWidgets('"View in My Bookings" opens the list of bookings', (tester) async {
      await openSuccess(tester);
      await tester.tap(find.text('View in My Bookings'));
      await tester.pumpAndSettle();

      expect(find.byType(MyBookingsPage), findsOneWidget);
      expect(api.called('myBookings'), hasLength(1));
    });
  });

  group('Email notice after booking, based on the backend notification status', () {
    Future<void> bookWithNotification(WidgetTester tester, Map<String, dynamic> notification) async {
      final repository = FakeBookingRepository()..response = {'booking': booking, 'notification': notification};
      await pumpPage(tester, BookingPage(allocation: allocation, repository: repository, api: api));
      await tester.tap(find.text('CONFIRM RESERVATION'));
      await tester.pumpAndSettle();
    }

    testWidgets('"accepted": the hiker is told the email was sent', (tester) async {
      await bookWithNotification(tester, {'status': 'accepted', 'messageId': 'm1'});
      expect(find.textContaining(emailText), findsOneWidget);
    });

    // [BUG] BookingPage sets notificationSent = response['notification'] != null.
    // The backend always returns a notification object, with status 'accepted',
    // 'failed' or 'disabled', so the page claims the email was sent even when it
    // failed. It should check notification['status'] == 'accepted'. Fails until fixed.
    testWidgets('[BUG] "failed": the hiker is not told the email was sent', (tester) async {
      await bookWithNotification(tester, {'status': 'failed'});
      expect(find.textContaining(emailText), findsNothing);
    });

    testWidgets('[BUG] "disabled": the hiker is not told the email was sent', (tester) async {
      await bookWithNotification(tester, {'status': 'disabled'});
      expect(find.textContaining(emailText), findsNothing);
    });
  });
}
