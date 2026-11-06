// MH-05 Provide party requirements — E2E (real app + real backend)
// As a hiker I can add dietary needs and allergies for (part of) my party when booking.
import 'package:flutter/material.dart';
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
    await createSlot(day, '19:00', '20:00', tablesOf([4]));
    hiker = await newHiker();
  });

  Future<void> openBookingPage(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await waitFor(tester, find.text('My Bookings'));
    await chooseSearchDate(tester, day);
    await setGuests(tester, 4);
    await checkAvailability(tester);
    await tap(tester, find.text('Proceed to Reservation'));
    await waitFor(tester, find.text('CONFIRM RESERVATION'));
  }

  Future<void> addRequirement(WidgetTester tester, String text, {bool allergy = false}) async {
    await tap(tester, find.text('Add Dietary / Allergy Requirement'));
    await type(tester, find.byType(TextField).last, text);
    if (allergy) await tap(tester, find.byType(Checkbox).last);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tap(tester, find.text('CONFIRM RESERVATION'));
    await waitFor(tester, find.text('Your table is reserved!'));
  }

  testWidgets('example from the story: requirements for subsets of the party are stored with their allergy flag',
      (tester) async {
    await openBookingPage(tester);
    await addRequirement(tester, '1 vegan, peanut allergy', allergy: true);
    await addRequirement(tester, '2 vegetarians');
    await confirm(tester);

    final booking = (await bookingsOf(hiker)).single;
    final stored = [
      for (final r in booking['requirements'] as List) {'description': r['description'], 'allergy': r['allergy']},
    ];
    expect(stored, unorderedEquals([
      {'description': '1 vegan, peanut allergy', 'allergy': true},
      {'description': '2 vegetarians', 'allergy': false},
    ]));
  });

  testWidgets('the confirmation lists the requirements and flags the allergy for the kitchen', (tester) async {
    await openBookingPage(tester);
    await addRequirement(tester, 'peanut allergy', allergy: true);
    await confirm(tester);

    expect(find.textContaining('peanut allergy'), findsWidgets);
    expect(find.text('KITCHEN ALERT'), findsOneWidget);
  });

  testWidgets('requirements are optional', (tester) async {
    await openBookingPage(tester);
    await confirm(tester);

    final booking = (await bookingsOf(hiker)).single;
    expect(booking['requirements'], isEmpty);
  });

  testWidgets('an empty requirement blocks the booking until it is filled', (tester) async {
    await openBookingPage(tester);
    await tap(tester, find.text('Add Dietary / Allergy Requirement'));
    await tap(tester, find.text('CONFIRM RESERVATION'));

    expect(find.text('Complete or remove empty requirements.'), findsOneWidget);
    expect(await bookingsOf(hiker), isEmpty);
  });
}
