// MH-04 Check availability — integration tests (ExplorePage, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeApi api;

  final lunch = {
    'tsID': 3,
    'start_time': '2026-12-01 12:00',
    'end_time': '2026-12-01 13:00',
    'tables': [{'table_no': 1, 'seats': 2}, {'table_no': 2, 'seats': 2}, {'table_no': 3, 'seats': 2}],
  };
  final dinner = {'tsID': 4, 'start_time': '2026-12-01 19:00', 'end_time': '2026-12-01 20:30', 'tables': []};

  setUp(() {
    api = FakeApi()..slots = [lunch, dinner]; // nobody is logged in (currentUser -> 401)
  });

  Future<void> open(WidgetTester tester) =>
      pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));

  Future<void> check(WidgetTester tester) async {
    await tester.tap(find.text('Check Availability'));
    await tester.pumpAndSettle();
  }

  testWidgets('is public: a visitor without login sees the meal slots of the day', (tester) async {
    await open(tester);
    expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
    expect(find.text('Dinner 19:00 - 20:30'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('sends the selected slot time and party size (default 6)', (tester) async {
    await open(tester);
    await check(tester);
    expect(api.called('checkAvailability').single.args, containsPair('time', '12:00'));
    expect(api.called('checkAvailability').single.args, containsPair('partySize', 6));
  });

  testWidgets('party size and slot can be changed before checking', (tester) async {
    await open(tester);
    for (final icon in [Icons.add, Icons.add, Icons.remove]) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
    }
    await tester.tap(find.text('Dinner 19:00 - 20:30'));
    await tester.pump();
    expect(find.textContaining('7 Guests', findRichText: true), findsOneWidget);

    await check(tester);
    expect(api.called('checkAvailability').single.args, containsPair('time', '19:00'));
    expect(api.called('checkAvailability').single.args, containsPair('partySize', 7));
  });

  testWidgets('example from the story: 6 seats over 3 tables of 2 shows the 2 + 2 + 2 breakdown', (tester) async {
    api.availability = {
      'available': true,
      'partySize': 6,
      'slot': {'tsID': 3, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:00'},
      'allocation': [
        {'table_no': 1, 'seats': 2},
        {'table_no': 2, 'seats': 2},
        {'table_no': 3, 'seats': 2},
      ],
    };
    await open(tester);
    await check(tester);

    expect(find.text('Available (Shared Seating)'), findsOneWidget);
    expect(find.text('6 Total Seats'), findsOneWidget);
    for (final table in ['Table 1', 'Table 2', 'Table 3']) {
      expect(find.text(table), findsOneWidget);
    }
    expect(find.text('2 of 2 bench spots'), findsNWidgets(3));
    expect(find.text('Proceed to Reservation'), findsOneWidget);
  });

  testWidgets('answers no when the party does not fit, and offers no booking', (tester) async {
    api.availability = {'available': false, 'partySize': 6, 'slot': null, 'allocation': []};
    await open(tester);
    await check(tester);

    expect(find.text('No availability found for this slot'), findsOneWidget);
    expect(find.text('Proceed to Reservation'), findsNothing);
  });

  testWidgets('changing the party size after a check hides the old answer', (tester) async {
    api.availability = {'available': false, 'allocation': []};
    await open(tester);
    await check(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('No availability found for this slot'), findsNothing);
  });

  testWidgets('a day without slots says so and cannot be checked', (tester) async {
    api.slots = [];
    await open(tester);

    expect(find.text('No meal service slots are available for this date.'), findsOneWidget);
    await check(tester);
    expect(api.called('checkAvailability'), isEmpty);
  });

  testWidgets('when slots cannot be loaded, the error can be retried', (tester) async {
    api.slotsError = const ApiException(503, 'DATABASE_BUSY', 'Please retry shortly');
    await open(tester);
    expect(find.text('Please retry shortly'), findsOneWidget);

    api.slotsError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
    expect(api.called('listSlots'), hasLength(2));
  });

  testWidgets('an error from the availability check is shown to the user', (tester) async {
    api.availabilityError = const ApiException(400, 'VALIDATION_ERROR', 'partySize must be a positive integer');
    await open(tester);
    await check(tester);
    expect(find.text('partySize must be a positive integer'), findsOneWidget);
  });
}
