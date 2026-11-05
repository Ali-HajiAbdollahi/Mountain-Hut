// MH-01 Book a table — E2E (real app + real backend)
// As a hiker I can book a table for my party in a meal slot.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(checkBackend);

  /// Explore page: chooses [day], sets [guests], checks availability and proceeds.
  Future<void> checkAndProceed(WidgetTester tester, DateTime day, int guests) async {
    await chooseSearchDate(tester, day);
    await setGuests(tester, guests);
    await checkAvailability(tester);
    await tap(tester, find.text('Proceed to Reservation'));
  }

  Future<void> confirmReservation(WidgetTester tester) async {
    await tap(tester, find.text('CONFIRM RESERVATION'));
    await waitFor(tester, find.text('Your table is reserved!'));
  }

  testWidgets('a new visitor registers during the reservation and books the table', (tester) async {
    final day = await freshDay();
    final slotId = await createSlot(day, '12:00', '13:00', tablesOf([4, 4]));
    final hiker = (email: uniqueEmail(), name: 'Anna Bianchi');

    await launchApp(tester);
    await checkAndProceed(tester, day, 4);

    // the reservation asks for an account: registration is offered first
    await waitFor(tester, find.text('Hiker Registration'));
    await type(tester, fieldWithHint('Elena Rostova'), hiker.name);
    await type(tester, fieldWithHint('elena.rostova@alps.org'), hiker.email);
    await type(tester, fieldWithHint('+43 664 1234567'), '+39 333 1234567');
    await type(tester, fieldWithHint('••••••••••••'), password);
    await tap(tester, find.text('Create Account & Continue Booking'));

    await waitFor(tester, find.text('CONFIRM RESERVATION'));
    expect(find.text(mdy(day)), findsOneWidget);
    expect(find.text('4 Guests'), findsOneWidget);
    await confirmReservation(tester);

    // the booking really exists on the server, for that hiker, slot and party size
    final booking = (await bookingsOf(hiker)).single;
    expect(booking['tsID'], slotId);
    expect(booking['n_people'], 4);
    expect(booking['contact_name'], 'Anna Bianchi');
    expect(find.text('#${booking['reference']}'), findsOneWidget);
  });

  testWidgets('a registered hiker signs in during the reservation and books', (tester) async {
    final day = await freshDay();
    await createSlot(day, '19:00', '20:00', tablesOf([2, 6]));
    final hiker = await newHiker('Paolo Rossi');

    await launchApp(tester);
    await checkAndProceed(tester, day, 2);
    await signIn(tester, hiker.email, continueBooking: true);
    await confirmReservation(tester);

    final booking = (await bookingsOf(hiker)).single;
    expect(booking['n_people'], 2);
    expect(booking['tables'], [{'table_no': 1, 'seats': 2}]);
  });

  testWidgets('a hiker already signed in goes straight from availability to booking', (tester) async {
    final day = await freshDay();
    await createSlot(day, '12:00', '13:00', tablesOf([6]));
    final hiker = await newHiker();

    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await waitFor(tester, find.text('My Bookings'));
    await checkAndProceed(tester, day, 6);

    expect(find.text('Hiker Registration'), findsNothing);
    await confirmReservation(tester);
    expect(await bookingsOf(hiker), hasLength(1));
  });

  testWidgets('seats taken by a booking are no longer offered to others', (tester) async {
    final day = await freshDay();
    final slotId = await createSlot(day, '12:00', '13:00', tablesOf([4]));
    await bookAs(await newHiker(), slotId, 4);

    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await setGuests(tester, 2);
    await checkAvailability(tester);

    expect(find.text('No availability found for this slot'), findsOneWidget);
  });

  testWidgets('an employee account cannot book as a hiker', (tester) async {
    final day = await freshDay();
    await createSlot(day, '12:00', '13:00', tablesOf([6]));

    await launchApp(tester);
    await checkAndProceed(tester, day, 6);
    await signIn(tester, staffEmail, continueBooking: true);

    await waitFor(tester, find.text('Staff Portal'));
    expect(find.text('CONFIRM RESERVATION'), findsNothing);
  });
}
