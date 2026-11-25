// MH-09 Repeat a weekly schedule — integration tests (SlotCapacitySection, "Copy weeks" calendar, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/iso_week.dart';
import 'package:client/features/staff_portal/domain/entities/service_slot.dart';
import 'package:client/features/staff_portal/presentation/widgets/slot_capacity_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
final _thisWeek = isoWeekStart(_today);

DateTime _day(DateTime monday, int offset) => DateTime(monday.year, monday.month, monday.day + offset);

/// The Monday [n] weeks after the current one.
DateTime _week(int n) => _day(_thisWeek, 7 * n);

final _nextWeek = _week(1);

/// "Nov 30 – Dec 6": Monday to Sunday, as in the dialog.
String _weekLabel(DateTime monday) {
  const l = DefaultMaterialLocalizations();
  return '${l.formatShortMonthDay(monday)} – ${l.formatShortMonthDay(_day(monday, 6))}';
}

Map<String, dynamic> _slot(int tsID, DateTime day, String start, String end) =>
    slotJson(tsID: tsID, start: '${formatYmd(day)} $start', end: '${formatYmd(day)} $end');

const _copyTo1 = 'COPY TO 1 WEEK';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi()..slots = [];
  });

  Future<void> open(WidgetTester tester) =>
      pumpPage(tester, Scaffold(body: SlotCapacitySection(api: api)));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // Copying weeks is a secondary action of the Planning tab, in a dialog.
  Future<void> openCopyWeeks(WidgetTester tester) => tap(tester, find.byKey(copyWeeksButtonKey));

  Future<void> openDialog(WidgetTester tester) async {
    await open(tester);
    await openCopyWeeks(tester);
  }

  Finder weekRow(DateTime monday) => find.byKey(ValueKey('copy-week-${formatYmd(monday)}'));

  /// Shows on the calendar the month with the week of [monday], then taps that week.
  Future<void> tapWeek(WidgetTester tester, DateTime monday) async {
    for (var i = 0; i < 3 && weekRow(monday).evaluate().isEmpty; i++) {
      await tap(tester, find.byTooltip('Next month'));
    }
    for (var i = 0; i < 6 && weekRow(monday).evaluate().isEmpty; i++) {
      await tap(tester, find.byTooltip('Previous month'));
    }
    await tap(tester, weekRow(monday));
  }

  ButtonStyleButton button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()));

  // While a confirmation is open the copy button shows a spinner, so the screen never settles.
  Future<void> pressWithoutSettling(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> answer(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Iterable<String> listedDates() => api.called('listSlots').map((c) => c.args['date'] as String);
  Iterable<Map<String, Object?>> copies() => api.called('repeatWeek').map((c) => c.args);

  group('Opening the dialog', () {
    testWidgets('"Copy weeks" opens a calendar; nothing is copied until asked', (tester) async {
      await open(tester);
      expect(find.text('Copy weeks'), findsOneWidget);
      expect(find.text('COPY WEEKS'), findsNothing);

      await openCopyWeeks(tester);
      expect(find.text('COPY WEEKS'), findsOneWidget);
      expect(weekRow(_thisWeek), findsOneWidget);

      await tap(tester, find.text('Close'));
      expect(find.text('COPY WEEKS'), findsNothing);
      expect(api.called('repeatWeek'), isEmpty);
    });

    testWidgets('by default copies the current week into the next one', (tester) async {
      await openDialog(tester);
      expect(find.text('From: ${_weekLabel(_thisWeek)}'), findsOneWidget);
      expect(find.text('To 1 week:'), findsOneWidget);
      expect(find.text(_weekLabel(_nextWeek)), findsOneWidget);

      await tap(tester, find.text(_copyTo1));
      expect(copies().single, {'sourceWeek': formatYmd(_thisWeek), 'targetWeek': formatYmd(_nextWeek)});
    });
  });

  group('Choosing the weeks on the calendar', () {
    testWidgets('tapping a week adds it to the weeks to fill, tapping it again removes it', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      expect(find.text('To 2 weeks:'), findsOneWidget);
      expect(find.text('COPY TO 2 WEEKS'), findsOneWidget);

      await tapWeek(tester, _nextWeek);
      expect(find.text('To 1 week:'), findsOneWidget);
      expect(find.text(_weekLabel(_week(2))), findsOneWidget);
      expect(find.text(_weekLabel(_nextWeek)), findsNothing);
    });

    testWidgets('a chip removes its week and "Clear" removes them all', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));

      await tap(tester, find.byTooltip('Remove ${_weekLabel(_nextWeek)}'));
      expect(find.text('To 1 week:'), findsOneWidget);

      await tap(tester, find.text('Clear'));
      expect(find.text('To 0 weeks:'), findsOneWidget);
      expect(find.text('No week chosen yet: tap the weeks to fill on the calendar.'), findsOneWidget);
      expect(button(tester, 'COPY').onPressed, isNull);
    });

    testWidgets('the week to copy is chosen on the calendar too', (tester) async {
      await openDialog(tester);
      await tap(tester, find.text('Week to copy'));
      await tapWeek(tester, _nextWeek);
      // the next week is now the one to copy, so it is no longer a week to fill
      expect(find.text('From: ${_weekLabel(_nextWeek)}'), findsOneWidget);
      expect(find.text('To 0 weeks:'), findsOneWidget);

      // after choosing the week to copy, taps choose the weeks to fill again
      await tapWeek(tester, _week(3));
      await tap(tester, find.text(_copyTo1));
      expect(copies().single, {'sourceWeek': formatYmd(_nextWeek), 'targetWeek': formatYmd(_week(3))});
    });

    testWidgets('the current week and past weeks cannot be filled', (tester) async {
      await openDialog(tester);
      await tap(tester, find.text('Week to copy'));
      await tapWeek(tester, _week(3));
      await tap(tester, find.text('Clear'));

      await tapWeek(tester, _thisWeek);
      await tapWeek(tester, _week(-1));
      expect(find.text('To 0 weeks:'), findsOneWidget);
    });
  });

  group('Copying into empty weeks', () {
    testWidgets('copies into every chosen week, one request per week, and says how many slots', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      await tapWeek(tester, _week(3));
      await tap(tester, find.text('COPY TO 3 WEEKS'));

      expect(find.text('Replace existing slots?'), findsNothing);
      expect(copies().map((c) => c['targetWeek']), [formatYmd(_nextWeek), formatYmd(_week(2)), formatYmd(_week(3))]);
      expect(copies().map((c) => c['sourceWeek']).toSet(), {formatYmd(_thisWeek)});
      expect(find.text('Copied 9 service slots into 3 weeks.'), findsOneWidget);
      expect(find.text('COPY WEEKS'), findsNothing);
    });

    testWidgets('uses the singular for one slot in one week', (tester) async {
      api.repeatedSlots = 1;
      await openDialog(tester);
      await tap(tester, find.text(_copyTo1));
      expect(find.text('Copied 1 service slot into 1 week.'), findsOneWidget);
    });

    testWidgets('checks all seven days of every chosen week before copying', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      await tap(tester, find.text('COPY TO 2 WEEKS'));

      for (final week in [_nextWeek, _week(2)]) {
        for (var offset = 0; offset < 7; offset++) {
          expect(listedDates(), contains(formatYmd(_day(week, offset))));
        }
      }
    });
  });

  group('Copying into weeks that already have slots', () {
    setUp(() {
      api.slotsByDate = {
        formatYmd(_day(_nextWeek, 1)): [_slot(7, _day(_nextWeek, 1), '12:00', '13:00')],
        formatYmd(_day(_nextWeek, 5)): [
          _slot(8, _day(_nextWeek, 5), '12:00', '13:00'),
          _slot(9, _day(_nextWeek, 5), '19:00', '20:00'),
        ],
      };
    });

    testWidgets('asks once, listing the weeks that have slots', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      await pressWithoutSettling(tester, 'COPY TO 2 WEEKS');

      expect(find.text('Replace existing slots?'), findsOneWidget);
      expect(find.text('This week already has slots:'), findsOneWidget);
      expect(find.text('• Week starting ${formatYmd(_nextWeek)}: 3 slots'), findsOneWidget);
      expect(find.textContaining(formatYmd(_week(2))), findsNothing);
      expect(api.called('repeatWeek'), isEmpty);
    });

    testWidgets('"Cancel" copies nothing and keeps the dialog open', (tester) async {
      await openDialog(tester);
      await pressWithoutSettling(tester, _copyTo1);
      await answer(tester, 'Cancel');

      expect(find.text('Replace existing slots?'), findsNothing);
      expect(api.called('repeatWeek'), isEmpty);
      expect(find.text('COPY WEEKS'), findsOneWidget);
      expect(button(tester, _copyTo1).onPressed, isNotNull);
    });

    testWidgets('"Replace" copies every chosen week', (tester) async {
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      await pressWithoutSettling(tester, 'COPY TO 2 WEEKS');
      await answer(tester, 'Replace');

      expect(copies(), hasLength(2));
      expect(find.text('Copied 6 service slots into 2 weeks.'), findsOneWidget);
    });
  });

  group('Weeks that cannot be copied', () {
    testWidgets('a refused week is listed with the reason, the other weeks are copied', (tester) async {
      api.repeatWeekErrorsByTarget = {
        formatYmd(_week(2)):
            const ApiException(409, 'CONFLICT', 'The target week has reservations: it cannot be replaced'),
      };
      await openDialog(tester);
      await tapWeek(tester, _week(2));
      await tap(tester, find.text('COPY TO 2 WEEKS'));

      expect(copies(), hasLength(2));
      expect(find.text('Copied 3 service slots into 1 week.'), findsOneWidget);
      expect(find.text('Not copied:'), findsOneWidget);
      expect(find.text('• ${_weekLabel(_week(2))}: The target week has reservations: it cannot be replaced'),
          findsOneWidget);
      // only the refused week is still chosen
      expect(find.text('To 1 week:'), findsOneWidget);
      expect(find.text(_weekLabel(_week(2))), findsOneWidget);
    });

    testWidgets('an empty source week is reported and nothing is copied', (tester) async {
      api.repeatWeekError = const ApiException(400, 'VALIDATION_ERROR', 'Source week has no slots');
      await openDialog(tester);
      await tap(tester, find.text(_copyTo1));

      expect(find.text('• ${_weekLabel(_nextWeek)}: Source week has no slots'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Copied \d')), findsNothing);
      expect(find.text('COPY WEEKS'), findsOneWidget);
    });
  });

  group('Refresh', () {
    testWidgets('when the day on screen is in a copied week, its slots are reloaded', (tester) async {
      final shown = _day(_nextWeek, 2);
      await open(tester);
      await tap(tester, find.text('Change'));
      await tap(tester, find.byIcon(Icons.edit_outlined));
      String two(int n) => n.toString().padLeft(2, '0');
      await tester.enterText(find.byType(TextField).last, '${two(shown.month)}/${two(shown.day)}/${shown.year}');
      await tap(tester, find.text('OK'));
      final before = listedDates().where((d) => d == formatYmd(shown)).length;

      await openCopyWeeks(tester);
      await tap(tester, find.text(_copyTo1));
      expect(listedDates().where((d) => d == formatYmd(shown)).length, before + 2);
    });

    testWidgets('when the day on screen is not in a copied week, it is not reloaded', (tester) async {
      await openDialog(tester);
      final before = listedDates().where((d) => d == formatYmd(_today)).length;
      await tap(tester, find.text(_copyTo1));
      expect(listedDates().where((d) => d == formatYmd(_today)).length, before);
    });
  });
}
