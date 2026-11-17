// MH-09 Repeat a weekly schedule — E2E (real app + real backend)
// As an employee I can copy the schedule of a week into another week, so that I do not
// have to configure recurring slots one by one. Clarification: a week that already has a
// schedule is completely replaced, unless it has reservations.
import 'dart:math';

import 'package:client/core/utils/iso_week.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

const _replicate = 'REPLICATE SCHEDULE TO TARGET';
const _confirmTitle = 'Replace weekly schedule?';

final _random = Random();

DateTime _day(DateTime monday, int offset) => DateTime(monday.year, monday.month, monday.day + offset);

/// A future Monday (5 to 45 weeks ahead) whose seven days have no slots yet.
Future<DateTime> _freshWeek() async {
  final thisWeek = isoWeekStart(DateTime.now());
  for (var attempt = 0; attempt < 20; attempt++) {
    final monday = _day(thisWeek, 7 * (5 + _random.nextInt(40)));
    final days = await Future.wait([for (var i = 0; i < 7; i++) slotsOn(_day(monday, i))]);
    if (days.every((slots) => slots.isEmpty)) return monday;
  }
  throw StateError('No free week found');
}

/// The slots of the seven days of the week starting [monday], as 'YYYY-MM-DD HH:MM' pairs.
Future<List<List<String>>> _scheduleOf(DateTime monday) async {
  final days = await Future.wait([for (var i = 0; i < 7; i++) slotsOn(_day(monday, i))]);
  return [
    for (final slot in days.expand((d) => d)) [slot['start_time'] as String, slot['end_time'] as String],
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime source;
  late DateTime target;

  setUpAll(checkBackend);

  setUp(() async {
    source = await _freshWeek();
    await createSlot(source, '12:00', '13:00', tablesOf([4, 2]));
    await createSlot(_day(source, 6), '19:00', '20:30', tablesOf([6]));
    target = await _freshWeek();
  });

  Future<void> openStaffPortal(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Staff Portal'));
    await waitFor(tester, find.text('WEEKLY SCHEDULE REPLICATION'));
  }

  Future<void> chooseWeeks(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Choose SOURCE WEEK'));
    await typeInDatePicker(tester, _day(source, 2));
    await tap(tester, find.byTooltip('Choose TARGET WEEK'));
    await typeInDatePicker(tester, _day(target, 4));
  }

  Future<void> pressReplicate(WidgetTester tester) async {
    await waitFor(tester, find.text(_replicate));
    await tester.ensureVisible(find.text(_replicate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_replicate));
    await tester.pump();
  }

  Future<void> waitWithoutSettling(WidgetTester tester, Finder finder) async {
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) fail('Timed out waiting for: $finder\n${describeScreen()}');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> answer(WidgetTester tester, String button) async {
    await tester.tap(find.text(button));
    await tester.pump();
  }

  testWidgets('the employee copies a week into an empty week: same days, times and tables', (tester) async {
    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressReplicate(tester);
    await waitFor(tester, find.text('Replicated 2 service slots to the target week.'));

    expect(find.text(_confirmTitle), findsNothing);
    expect(await _scheduleOf(target), [
      ['${ymd(target)} 12:00', '${ymd(target)} 13:00'],
      ['${ymd(_day(target, 6))} 19:00', '${ymd(_day(target, 6))} 20:30'],
    ]);
    expect((await slotsOn(target)).single['capacity'], 6);
    expect((await slotsOn(_day(target, 6))).single['capacity'], 6);
    expect(await _scheduleOf(source), hasLength(2));
  });

  testWidgets('a visitor sees the copied slots of the new week', (tester) async {
    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressReplicate(tester);
    await waitFor(tester, find.text('Replicated 2 service slots to the target week.'));

    await launchApp(tester);
    await chooseSearchDate(tester, target);
    expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
    await setGuests(tester, 6);
    await checkAvailability(tester);
    expect(find.text('Proceed to Reservation'), findsOneWidget);
  });

  testWidgets('a week with slots but no reservations is replaced after confirmation', (tester) async {
    await createSlot(_day(target, 1), '11:00', '12:00', tablesOf([10]));
    await createSlot(_day(target, 3), '20:00', '21:00', tablesOf([10]));

    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressReplicate(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    expect(find.textContaining('The week starting ${ymd(target)} has 2 slots.'), findsOneWidget);

    await answer(tester, 'Replace week');
    await waitFor(tester, find.text('Replicated 2 service slots to the target week.'));

    expect(await _scheduleOf(target), [
      ['${ymd(target)} 12:00', '${ymd(target)} 13:00'],
      ['${ymd(_day(target, 6))} 19:00', '${ymd(_day(target, 6))} 20:30'],
    ]);
  });

  testWidgets('"Cancel" in the confirmation leaves the target week as it was', (tester) async {
    await createSlot(_day(target, 1), '11:00', '12:00', tablesOf([10]));

    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressReplicate(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    await answer(tester, 'Cancel');
    await waitUntilGone(tester, find.text(_confirmTitle));

    expect(find.textContaining('Replicated'), findsNothing);
    expect(await _scheduleOf(target), [
      ['${ymd(_day(target, 1))} 11:00', '${ymd(_day(target, 1))} 12:00'],
    ]);
  });

  testWidgets('a week with a reservation is not replaced and the employee is told why', (tester) async {
    final booked = await createSlot(_day(target, 3), '12:00', '13:00', tablesOf([4]));
    await bookAs(await newHiker(), booked, 2);

    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressReplicate(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    await answer(tester, 'Replace week');
    await waitFor(tester, find.text('The target week has reservations: it cannot be replaced'));

    expect(find.textContaining('Replicated'), findsNothing);
    expect(await _scheduleOf(target), [
      ['${ymd(_day(target, 3))} 12:00', '${ymd(_day(target, 3))} 13:00'],
    ]);
  });
}
