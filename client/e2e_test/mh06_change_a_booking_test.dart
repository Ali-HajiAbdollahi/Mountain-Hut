// MH-06 Change a booking — E2E (real app + real backend)
// As a hiker I can change my booking (party size, slot, requirements) until 48 hours
// before the booked meal.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late int lunchId;
  late int dinnerId;
  late Hiker hiker;
  late Map<String, dynamic> booking;

  setUpAll(checkBackend);

  setUp(() async {
    day = await freshDay();
    lunchId = await createSlot(day, '12:00', '13:00', tablesOf([4, 4]));
    dinnerId = await createSlot(day, '19:00', '20:00', tablesOf([6]));
    hiker = await newHiker();
    booking = await bookAs(hiker, lunchId, 2, requirements: [{'description': 'nut allergy', 'allergy': true}]);
  });

  /// The booking as stored on the server (call it at the end: it closes the session).
  Future<Map<String, dynamic>> stored() async =>
      (await bookingsOf(hiker)).singleWhere((b) => b['bID'] == booking['bID']);

  Future<void> openMyBookings(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await tap(tester, find.text('My Bookings'));
    await waitFor(tester, find.text('REF  #${booking['reference']}'));
  }

  Future<void> openModifyModal(WidgetTester tester) async {
    await openMyBookings(tester);
    await tap(tester, find.text('EDIT / CHANGE BOOKING'));
    await waitFor(tester, find.text('MODIFY RESERVATION'));
    await waitFor(tester, find.text('12:00 - 13:00'));
  }

  Future<void> save(WidgetTester tester) async {
    await tap(tester, find.text('SAVE CHANGES'));
    await waitUntilGone(tester, find.text('MODIFY RESERVATION'));
  }

  testWidgets('My Bookings shows the booking made by the hiker', (tester) async {
    await openMyBookings(tester);

    expect(find.textContaining('2 Guests'), findsOneWidget);
    expect(find.text('nut allergy (Allergy Flag)'), findsOneWidget);
    expect(find.text('EDIT / CHANGE BOOKING'), findsOneWidget);
  });

  testWidgets('the party size can be changed and is saved on the server', (tester) async {
    await openModifyModal(tester);
    await tap(tester, find.widgetWithIcon(IconButton, Icons.add));
    await save(tester);

    await waitFor(tester, find.textContaining('3 Guests'));
    expect((await stored())['n_people'], 3);
  });

  testWidgets('the booking can be moved to another slot of the same day', (tester) async {
    await openModifyModal(tester);
    await tap(tester, find.text('12:00 - 13:00'));
    await tap(tester, find.text('19:00 - 20:00').last);
    await save(tester);

    expect((await stored())['tsID'], dinnerId);
  });

  testWidgets('a new allergy requirement is added to the booking', (tester) async {
    await openModifyModal(tester);
    await type(tester, find.byType(TextField), 'shellfish');
    await tap(tester, find.byType(CheckboxListTile));
    await tap(tester, find.text('ADD DIETARY / ALLERGY REQUIREMENT'));
    await save(tester);

    final requirements = [
      for (final r in (await stored())['requirements'] as List) {'description': r['description'], 'allergy': r['allergy']},
    ];
    expect(requirements, unorderedEquals([
      {'description': 'nut allergy', 'allergy': true},
      {'description': 'shellfish', 'allergy': true},
    ]));
  });

  testWidgets('a change that does not fit is refused and the booking stays as it was', (tester) async {
    await openModifyModal(tester);
    // 2 -> 9 people: more than the 8 seats of the lunch slot
    for (var i = 0; i < 7; i++) {
      await tap(tester, find.widgetWithIcon(IconButton, Icons.add));
    }
    await tap(tester, find.text('SAVE CHANGES'));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('MODIFY RESERVATION'), findsOneWidget); // the modal stays open with the error
    expect((await stored())['n_people'], 2);
  });

  testWidgets('less than 48 hours before the meal the booking is locked', (tester) async {
    // tomorrow, between 20:00 and 22:59: always less than 48 h but more than 2 h away
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final minute = Random().nextInt(180);
    final start = '${two(20 + minute ~/ 60)}:${two(minute % 60)}';
    final soonId = await createSlot(tomorrow, start, '23:59', tablesOf([4]));
    booking = await bookAs(hiker, soonId, 2);

    await openMyBookings(tester);
    final card = find.ancestor(of: find.text('REF  #${booking['reference']}'), matching: find.byType(Card));
    expect(find.descendant(of: card, matching: find.text('MODIFICATION LOCKED')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('EDIT / CHANGE BOOKING')), findsNothing);
  });
}
