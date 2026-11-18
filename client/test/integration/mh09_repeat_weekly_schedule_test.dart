// MH-09 Repeat a weekly schedule — integration tests (SlotCapacitySection, fake API)
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
final _nextWeek = _thisWeek.add(const Duration(days: 7));

DateTime _day(DateTime monday, int offset) => DateTime(monday.year, monday.month, monday.day + offset);

String _weekLabel(DateTime monday) {
  const l = DefaultMaterialLocalizations();
  return '${l.formatShortMonthDay(monday)} – ${l.formatShortMonthDay(isoWeekEndExclusive(monday))}';
}

Map<String, dynamic> _slot(int tsID, DateTime day, String start, String end) =>
    slotJson(tsID: tsID, start: '${formatYmd(day)} $start', end: '${formatYmd(day)} $end');

const _replicate = 'REPLICATE SCHEDULE TO TARGET';

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

  ButtonStyleButton replicateButton(WidgetTester tester) => tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(_replicate), matching: find.bySubtype<ButtonStyleButton>()));

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_replicate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_replicate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> answer(WidgetTester tester, String button) async {
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
  }

  Iterable<String> listedDates() => api.called('listSlots').map((c) => c.args['date'] as String);

  group('Choosing the weeks', () {
    testWidgets('by default copies the current week into the next one', (tester) async {
      await open(tester);

      expect(find.text('WEEKLY SCHEDULE REPLICATION'), findsOneWidget);
      expect(find.text('SOURCE WEEK'), findsOneWidget);
      expect(find.text('TARGET WEEK'), findsOneWidget);
      expect(find.text(_weekLabel(_thisWeek)), findsOneWidget);
      expect(find.text(_weekLabel(_nextWeek)), findsOneWidget);
    });

    testWidgets('the arrows move the target week forwards and backwards', (tester) async {
      await open(tester);
      await tap(tester, find.byTooltip('Next week').last);
      expect(find.text(_weekLabel(_nextWeek.add(const Duration(days: 7)))), findsOneWidget);

      await tap(tester, find.byTooltip('Previous week').last);
      await tap(tester, find.byTooltip('Previous week').last);
      expect(find.text(_weekLabel(_thisWeek)), findsNWidgets(2));
    });

    testWidgets('the same week twice cannot be copied', (tester) async {
      await open(tester);
      await tap(tester, find.byTooltip('Previous week').last);

      expect(find.text('Choose two different weeks.'), findsOneWidget);
      expect(replicateButton(tester).onPressed, isNull);

      await tap(tester, find.byTooltip('Next week').first);
      expect(find.text('Choose two different weeks.'), findsNothing);
      expect(replicateButton(tester).onPressed, isNotNull);
    });

    testWidgets('a day chosen in the calendar selects the Monday of its week', (tester) async {
      final wednesday = _day(_thisWeek, 23);
      await open(tester);
      await tap(tester, find.byTooltip('Choose TARGET WEEK'));
      await tap(tester, find.byIcon(Icons.edit_outlined));
      String two(int n) => n.toString().padLeft(2, '0');
      await tester.enterText(find.byType(TextField).last,
          '${two(wednesday.month)}/${two(wednesday.day)}/${wednesday.year}');
      await tap(tester, find.text('OK'));

      expect(find.text(_weekLabel(isoWeekStart(wednesday))), findsOneWidget);
      await tap(tester, find.text(_replicate));
      expect(api.called('repeatWeek').single.args['targetWeek'], formatYmd(isoWeekStart(wednesday)));
    });
  });

  group('Copying into an empty week', () {
    testWidgets('copies right away, without asking, and sends both Mondays', (tester) async {
      await open(tester);
      await tap(tester, find.text(_replicate));

      expect(find.text('Replace weekly schedule?'), findsNothing);
      expect(api.called('repeatWeek').single.args,
          {'sourceWeek': formatYmd(_thisWeek), 'targetWeek': formatYmd(_nextWeek)});
    });

    testWidgets('checks all seven days of the target week before copying', (tester) async {
      await open(tester);
      await tap(tester, find.text(_replicate));

      for (var offset = 0; offset < 7; offset++) {
        expect(listedDates(), contains(formatYmd(_day(_nextWeek, offset))));
      }
    });

    testWidgets('says how many slots were copied', (tester) async {
      await open(tester);
      await tap(tester, find.text(_replicate));
      expect(find.text('Replicated 3 service slots to the target week.'), findsOneWidget);
    });

    testWidgets('uses the singular for a single slot', (tester) async {
      api.repeatedSlots = 1;
      await open(tester);
      await tap(tester, find.text(_replicate));
      expect(find.text('Replicated 1 service slot to the target week.'), findsOneWidget);
    });
  });

  group('Copying into a week that already has slots', () {
    setUp(() {
      api.slotsByDate = {
        formatYmd(_day(_nextWeek, 1)): [_slot(7, _day(_nextWeek, 1), '12:00', '13:00')],
        formatYmd(_day(_nextWeek, 5)): [
          _slot(8, _day(_nextWeek, 5), '12:00', '13:00'),
          _slot(9, _day(_nextWeek, 5), '19:00', '20:00'),
        ],
      };
    });

    testWidgets('asks for confirmation, saying how many slots will be replaced', (tester) async {
      await open(tester);
      await openConfirmation(tester);

      expect(find.text('Replace weekly schedule?'), findsOneWidget);
      expect(
        find.text('The week starting ${formatYmd(_nextWeek)} has 3 slots. '
            'Replacing it removes those slots and their menus.'),
        findsOneWidget,
      );
      expect(api.called('repeatWeek'), isEmpty);
    });

    testWidgets('"Cancel" closes the dialog and copies nothing', (tester) async {
      await open(tester);
      await openConfirmation(tester);
      await answer(tester, 'Cancel');

      expect(find.text('Replace weekly schedule?'), findsNothing);
      expect(api.called('repeatWeek'), isEmpty);
      expect(replicateButton(tester).onPressed, isNotNull);
    });

    testWidgets('"Replace week" copies the schedule', (tester) async {
      await open(tester);
      await openConfirmation(tester);
      await answer(tester, 'Replace week');

      expect(api.called('repeatWeek'), hasLength(1));
      expect(find.text('Replicated 3 service slots to the target week.'), findsOneWidget);
    });

    testWidgets('a week with reservations is refused and the server message is shown', (tester) async {
      api.repeatWeekError =
          const ApiException(409, 'CONFLICT', 'The target week has reservations: it cannot be replaced');
      await open(tester);
      await openConfirmation(tester);
      await answer(tester, 'Replace week');

      expect(find.text('The target week has reservations: it cannot be replaced'), findsOneWidget);
      expect(find.textContaining('Replicated'), findsNothing);
      expect(replicateButton(tester).onPressed, isNotNull);
    });
  });

  group('Errors and refresh', () {
    testWidgets('an empty source week is reported with the server message', (tester) async {
      api.repeatWeekError = const ApiException(400, 'VALIDATION_ERROR', 'Source week has no slots');
      await open(tester);
      await tap(tester, find.text(_replicate));
      expect(find.text('Source week has no slots'), findsOneWidget);
    });

    testWidgets('when the day on screen is in the target week, its slots are reloaded', (tester) async {
      final shown = _day(_nextWeek, 2);
      await open(tester);
      await tap(tester, find.text('Change'));
      await tap(tester, find.byIcon(Icons.edit_outlined));
      String two(int n) => n.toString().padLeft(2, '0');
      await tester.enterText(find.byType(TextField).last, '${two(shown.month)}/${two(shown.day)}/${shown.year}');
      await tap(tester, find.text('OK'));
      final before = listedDates().where((d) => d == formatYmd(shown)).length;

      await tap(tester, find.text(_replicate));
      expect(listedDates().where((d) => d == formatYmd(shown)).length, before + 2);
    });

    testWidgets('when the day on screen is not in the target week, it is not reloaded', (tester) async {
      await open(tester);
      final before = listedDates().where((d) => d == formatYmd(_today)).length;
      await tap(tester, find.text(_replicate));
      expect(listedDates().where((d) => d == formatYmd(_today)).length, before);
    });
  });
}
