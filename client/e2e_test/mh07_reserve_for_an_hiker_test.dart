// MH-07 Reserve for an hiker — E2E (real app + real backend)
// As an employee I can make a booking for a hiker who calls or walks in: I look the
// hiker up and, if not registered, I add them (temporary or regular profile), then I
// choose date, slot, party size and requirements.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late int slotId;

  setUpAll(checkBackend);

  setUp(() async {
    day = await freshDay();
    slotId = await createSlot(day, '12:00', '13:00', tablesOf([6]));
  });

  Future<void> openWalkInTab(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Staff Portal'));
    await tap(tester, find.text('Phone / Walk-in Booking'));
    await waitFor(tester, find.text('QUICK HIKER LOOKUP'));
  }

  Future<void> searchHiker(WidgetTester tester, String text) async {
    await type(tester, fieldWithHint('Search by name, mobile, or email…'), text);
    await tester.pump(const Duration(milliseconds: 500)); // lookup debounce
  }

  /// Step 2 and 3: chooses [day], the lunch slot and [people], then confirms.
  Future<void> bookLunch(WidgetTester tester, {int people = 1}) async {
    await waitFor(tester, find.text('2. BOOKING DETAILS'));
    await tap(tester, find.text('Change date'));
    await typeInDatePicker(tester, day);
    await tap(tester, find.text('12:00 – 13:00'));
    for (var i = 1; i < people; i++) {
      await tap(tester, find.byIcon(Icons.add_circle_outline));
    }
    await tap(tester, find.text('Confirm Booking'));
    await waitFor(tester, find.textContaining('created'));
  }

  testWidgets('the employee books for a registered hiker, who then sees it in My Bookings', (tester) async {
    final code = '${Random().nextInt(1 << 30)}';
    final name = 'Walkin $code';
    final hiker = await newHiker(name);

    await openWalkInTab(tester);
    await searchHiker(tester, code); // not the full name: the field would match find.text(name)
    await tap(tester, find.text(name));
    await tap(tester, find.text('Confirm Hiker'));
    await bookLunch(tester, people: 3);

    // the hiker opens the app and finds the booking made by the employee
    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await tap(tester, find.text('My Bookings'));
    await waitFor(tester, find.textContaining('REF  #MH-'));
    expect(find.textContaining('3 Guests'), findsOneWidget);

    final booking = (await bookingsOf(hiker)).single;
    expect(booking['tsID'], slotId);
    expect(booking['n_people'], 3);
  });

  testWidgets('a hiker who is not registered is booked as a temporary guest', (tester) async {
    await openWalkInTab(tester);
    await searchHiker(tester, 'Nobody ${Random().nextInt(1 << 30)}');
    await waitFor(tester, find.textContaining('No registered hiker found'));
    await type(tester, fieldWithHint('e.g. Martin S. (Walk-in)'), 'Martin S. (Walk-in)');
    await type(tester, fieldWithHint('+41 79 123 4567'), '+41 79 000 0000');
    await tap(tester, find.text('Confirm Temporary Hiker'));
    await bookLunch(tester, people: 2);

    final slot = (await slotsOn(day)).single;
    expect(slot['free_seats'], 4); // 6 seats - 2 people
  });

  testWidgets('a new hiker gets a regular profile and can then sign in to see the booking', (tester) async {
    final hiker = (email: uniqueEmail(), name: 'Giulia Verdi');

    await openWalkInTab(tester);
    await searchHiker(tester, 'Giulia Verdi ${Random().nextInt(1 << 30)}');
    await waitFor(tester, find.textContaining('No registered hiker found'));
    await tap(tester, find.text('Regular Profile'));
    await type(tester, fieldWithHint('Elena Rossi'), hiker.name);
    await type(tester, fieldWithHint('elena.rossi@alpinists.ch'), hiker.email);
    await type(tester, fieldWithHint('+41 78 890 1234'), '+39 333 7654321');
    await type(tester, fieldWithHint('••••••••'), password);
    await tap(tester, find.text('Confirm Registration'));
    await bookLunch(tester, people: 4);

    final booking = (await bookingsOf(hiker)).single; // the new profile can log in
    expect(booking['n_people'], 4);
    expect(booking['contact_name'], 'Giulia Verdi');
  });

  testWidgets('the same registered hiker cannot be booked twice in the same slot', (tester) async {
    final code = '${Random().nextInt(1 << 30)}';
    final name = 'Walkin $code';
    final hiker = await newHiker(name);
    await bookAs(hiker, slotId, 2);

    await openWalkInTab(tester);
    await searchHiker(tester, code); // not the full name: the field would match find.text(name)
    await tap(tester, find.text(name));
    await tap(tester, find.text('Confirm Hiker'));
    await waitFor(tester, find.text('2. BOOKING DETAILS'));
    await tap(tester, find.text('Change date'));
    await typeInDatePicker(tester, day);
    await tap(tester, find.text('12:00 – 13:00'));
    await tap(tester, find.text('Confirm Booking'));

    await waitFor(tester, find.text('This hiker already has a booking in this slot'));
    expect(await bookingsOf(hiker), hasLength(1));
  });
}
