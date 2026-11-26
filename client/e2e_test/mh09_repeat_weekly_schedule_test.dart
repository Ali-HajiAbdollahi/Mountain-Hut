// MH-09 Repeat a weekly schedule — E2E (real app + real backend)
// As an employee I can copy the schedule of a week into other weeks, so that I do not
// have to configure recurring slots one by one. Clarification: a week that already has a
// schedule is completely replaced, unless it has reservations.
import 'dart:math';

import 'package:client/core/utils/iso_week.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

const _copy = 'COPY TO 1 WEEK';
const _confirmTitle = 'Replace existing slots?';
final _copiedMessage = RegExp(r'^Copied \d');

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
    await tap(tester, find.text('Dining'));
    await waitFor(tester, find.byKey(const ValueKey('copy-weeks-button')));
  }

  // The month shown by the calendar of the "Copy weeks" dialog.
  late DateTime shownMonth;

  /// Moves the calendar to the month of [monday] and taps that week.
  Future<void> tapWeek(WidgetTester tester, DateTime monday) async {
    final delta = (monday.year - shownMonth.year) * 12 + monday.month - shownMonth.month;
    for (var i = 0; i < delta.abs(); i++) {
      await tap(tester, find.byTooltip(delta > 0 ? 'Next month' : 'Previous month'));
    }
    shownMonth = DateTime(monday.year, monday.month);
    await tap(tester, find.byKey(ValueKey('copy-week-${ymd(monday)}')));
  }

  Future<void> chooseWeeks(WidgetTester tester) async {
    // the weeks are chosen on the calendar of the "Copy weeks" dialog of the Planning tab
    await tap(tester, find.byKey(const ValueKey('copy-weeks-button')));
    await waitFor(tester, find.text('COPY WEEKS'));
    final now = DateTime.now();
    shownMonth = DateTime(now.year, now.month);
    await tap(tester, find.text('Clear')); // by default the next week would be filled too
    await tap(tester, find.text('Week to copy'));
    await tapWeek(tester, source);
    await tapWeek(tester, target);
  }

  Future<void> pressCopy(WidgetTester tester) async {
    await waitFor(tester, find.text(_copy));
    await tester.ensureVisible(find.text(_copy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_copy));
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
    await pressCopy(tester);
    await waitFor(tester, find.text('Copied 2 service slots into 1 week.'));

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
    await pressCopy(tester);
    await waitFor(tester, find.text('Copied 2 service slots into 1 week.'));

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
    await pressCopy(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    expect(find.text('• Week starting ${ymd(target)}: 2 slots'), findsOneWidget);

    await answer(tester, 'Replace');
    await waitFor(tester, find.text('Copied 2 service slots into 1 week.'));

    expect(await _scheduleOf(target), [
      ['${ymd(target)} 12:00', '${ymd(target)} 13:00'],
      ['${ymd(_day(target, 6))} 19:00', '${ymd(_day(target, 6))} 20:30'],
    ]);
  });

  testWidgets('"Cancel" in the confirmation leaves the target week as it was', (tester) async {
    await createSlot(_day(target, 1), '11:00', '12:00', tablesOf([10]));

    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressCopy(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    await answer(tester, 'Cancel');
    await waitUntilGone(tester, find.text(_confirmTitle));

    expect(find.textContaining(_copiedMessage), findsNothing);
    expect(await _scheduleOf(target), [
      ['${ymd(_day(target, 1))} 11:00', '${ymd(_day(target, 1))} 12:00'],
    ]);
  });

  testWidgets('a week with a reservation is not replaced and the employee is told why', (tester) async {
    final booked = await createSlot(_day(target, 3), '12:00', '13:00', tablesOf([4]));
    await bookAs(await newHiker(), booked, 2);

    await openStaffPortal(tester);
    await chooseWeeks(tester);
    await pressCopy(tester);
    await waitWithoutSettling(tester, find.text(_confirmTitle));
    await answer(tester, 'Replace');
    await waitFor(tester, find.textContaining('The target week has reservations: it cannot be replaced'));

    expect(find.textContaining(_copiedMessage), findsNothing);
    expect(await _scheduleOf(target), [
      ['${ymd(_day(target, 3))} 12:00', '${ymd(_day(target, 3))} 13:00'],
    ]);
  });
}
