// MH-03 Receive confirmation — E2E (real app + real backend)
// As a hiker, after booking I receive a confirmation with the booking details.
// The E2E backend runs with MAIL_MODE=disabled, so no real email is sent.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late Hiker hiker;

  setUpAll(checkBackend);

  setUp(() async {
    day = await freshDay();
    await createSlot(day, '12:00', '13:00', tablesOf([2, 2]));
    hiker = await newHiker('Marta Conti');
  });

  /// Signs in, books lunch on [day] for 4 people and waits for the confirmation page.
  Future<void> bookThroughTheApp(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await waitFor(tester, find.text('My Bookings'));
    await chooseSearchDate(tester, day);
    await setGuests(tester, 4);
    await checkAvailability(tester);
    await tap(tester, find.text('Proceed to Reservation'));
    await tap(tester, find.text('CONFIRM RESERVATION'));
    await waitFor(tester, find.text('Your table is reserved!'));
  }

  testWidgets('the confirmation shows the reference and the details stored by the server', (tester) async {
    await bookThroughTheApp(tester);
    final booking = (await bookingsOf(hiker)).single;

    expect(find.text('#${booking['reference']}'), findsOneWidget);
    expect(find.text('Marta Conti'), findsOneWidget);
    expect(find.text(mdy(day)), findsOneWidget);
    expect(find.text('Lunch 12:00 – 13:00'), findsOneWidget);
    expect(find.text('4 Guests'), findsOneWidget);
    expect(find.text('Tables 1 & 2'), findsOneWidget);
    expect(find.text('No dietary requirements specified.'), findsOneWidget);
  });

  testWidgets('with email disabled on the server, the app does not claim an email was sent', (tester) async {
    await bookThroughTheApp(tester);
    expect(find.textContaining('A confirmation email has been sent'), findsNothing);
  });

  testWidgets('"View in My Bookings" shows the new booking', (tester) async {
    await bookThroughTheApp(tester);
    await tap(tester, find.text('View in My Bookings'));
    await waitFor(tester, find.textContaining('REF  #MH-'));
    expect(find.textContaining('4 Guests'), findsOneWidget);

    final booking = (await bookingsOf(hiker)).single; // checked last: it closes the session
    expect(find.text('REF  #${booking['reference']}'), findsOneWidget);
  });
}
