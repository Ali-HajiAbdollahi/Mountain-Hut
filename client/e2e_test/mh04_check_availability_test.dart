// MH-04 Check availability — E2E (real app + real backend)
// As a visitor (no login) I can check whether a party fits in a meal slot.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;

  setUpAll(() async {
    await checkBackend();
    day = await freshDay();
    await createSlot(day, '12:00', '13:00', tablesOf([2, 2, 2]));
    await createSlot(day, '19:00', '20:30', tablesOf([4]));
  });

  testWidgets('a visitor sees the meal slots of the chosen day', (tester) async {
    await launchApp(tester);
    await chooseSearchDate(tester, day);

    expect(find.text(mdy(day)), findsOneWidget);
    expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
    expect(find.text('Dinner 19:00 - 20:30'), findsOneWidget);
  });

  testWidgets('example from the story: 6 people over 3 tables of 2 are seated 2 + 2 + 2', (tester) async {
    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await checkAvailability(tester); // lunch, 6 guests (default)

    expect(find.text('Proceed to Reservation'), findsOneWidget);
    expect(find.text('6 Total Seats'), findsOneWidget);
    for (final table in ['Table 1', 'Table 2', 'Table 3']) {
      expect(find.text(table), findsOneWidget);
    }
  });

  testWidgets('a party larger than the free seats is told there is no availability', (tester) async {
    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await setGuests(tester, 7);
    await checkAvailability(tester);

    expect(find.text('No availability found for this slot'), findsOneWidget);
    expect(find.text('Proceed to Reservation'), findsNothing);
  });

  testWidgets('each slot is checked against its own tables', (tester) async {
    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await tap(tester, find.text('Dinner 19:00 - 20:30'));
    await setGuests(tester, 4);
    await checkAvailability(tester);

    expect(find.text('Proceed to Reservation'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Table 2'), findsNothing);
  });

  testWidgets('a day without slots says so', (tester) async {
    final emptyDay = await freshDay();
    await launchApp(tester);
    await chooseSearchDate(tester, emptyDay);

    expect(find.text('No meal service slots are available for this date.'), findsOneWidget);
  });
}
