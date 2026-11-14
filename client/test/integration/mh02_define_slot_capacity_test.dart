// MH-02 Define slot capacity — integration tests for service slots and table layouts.
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/staff_portal/domain/entities/service_slot.dart';
import 'package:client/features/staff_portal/domain/entities/table_draft.dart';
import 'package:client/features/staff_portal/presentation/widgets/slot_capacity_section.dart';
import 'package:client/features/staff_portal/presentation/widgets/staff_portal_body.dart';
import 'package:client/features/staff_portal/presentation/widgets/table_allocation_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

String _at(DateTime day, String hhmm) => '${formatYmd(day)} $hhmm';

/// 12:00–13:00 with tables 01 (2 seats) and 02 (4 seats).
Map<String, dynamic> _lunch({int tsID = 1, DateTime? day}) => slotJson(
  tsID: tsID,
  start: _at(day ?? _today, '12:00'),
  end: _at(day ?? _today, '13:00'),
  tables: [
    {'table_no': 1, 'seats': 2},
    {'table_no': 2, 'seats': 4},
  ],
);

/// 13:00–14:00 without a table layout.
Map<String, dynamic> _emptySlot({int tsID = 2}) => slotJson(
  tsID: tsID,
  start: _at(_today, '13:00'),
  end: _at(_today, '14:00'),
);

Future<void> _pumpSection(WidgetTester tester, FakeApi api) =>
    pumpPage(tester, Scaffold(body: SlotCapacitySection(api: api)));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Picks a day in the date picker of "TARGET OPERATIONAL DAY", typing it in input mode.
Future<void> _changeDay(WidgetTester tester, DateTime day) async {
  await _tap(tester, find.text('Change'));
  await _tap(tester, find.byIcon(Icons.edit_outlined));
  String two(int n) => n.toString().padLeft(2, '0');
  await tester.enterText(
    find.byType(TextField).last,
    '${two(day.month)}/${two(day.day)}/${day.year}',
  );
  await _tap(tester, find.text('OK'));
}

/// Picks a time in the time picker of [field] ("Start time" / "End time"), in input mode.
Future<void> _pickTime(
  WidgetTester tester,
  String field,
  int hour,
  int minute,
) async {
  await _tap(
    tester,
    find.ancestor(of: find.text(field), matching: find.byType(InkWell)).first,
  );
  await _tap(tester, find.byIcon(Icons.keyboard_outlined));
  final inputs = find.descendant(
    of: find.byType(Dialog).last,
    matching: find.byType(TextField),
  );
  await tester.enterText(inputs.at(0), hour.toString().padLeft(2, '0'));
  await tester.enterText(inputs.at(1), minute.toString().padLeft(2, '0'));
  await _tap(tester, find.text('OK'));
}

/// The test font draws every letter as a full 1em square, while the real font (Roboto) is about
/// 0.55em wide: in the table modal (max 440 px) the rows would overflow only because of the test
/// font, pushing buttons out of the dialog. Scaling the text to 0.6 gives realistic widths.
void staffTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await body(tester);
  });
}

void main() {
  group('Staff portal', () {
    testWidgets(
      'opens on "Define Slot Capacity" and loads the slots of today',
      (tester) async {
        final api = FakeApi()..slots = [_lunch()];
        await pumpPage(tester, Scaffold(body: StaffPortalBody(api: api)));

        expect(find.text('Define Slot Capacity'), findsOneWidget);
        expect(find.text('Phone / Walk-in Booking'), findsOneWidget);
        expect(find.text('SERVICE SLOTS'), findsOneWidget);
        expect(api.called('listSlots').single.args['date'], formatYmd(_today));
      },
    );
  });

  group('Service slots of the day', () {
    testWidgets(
      'shows today, every slot with duration and capacity, the first one active',
      (tester) async {
        final api = FakeApi()..slots = [_emptySlot(), _lunch()];
        await _pumpSection(tester, api);

        expect(find.text(formatLongDate(_today)), findsOneWidget);
        expect(find.text('2 slots configured'), findsOneWidget);
        expect(find.text('12:00 – 13:00'), findsOneWidget);
        expect(find.text('60 min · 6 seats'), findsOneWidget);
        expect(find.text('13:00 – 14:00'), findsOneWidget);
        expect(find.text('60 min · no layout yet'), findsOneWidget);
        // slots are sorted by start time: the 12:00 one comes first and is active
        expect(find.text('ACTIVE SLOT'), findsOneWidget);
        expect(find.text('Tables: 01 (2), 02 (4)'), findsOneWidget);
        expect(find.text('6 Seats'), findsOneWidget);
      },
    );

    testWidgets('tapping another slot makes it the active one', (tester) async {
      final api = FakeApi()..slots = [_lunch(), _emptySlot()];
      await _pumpSection(tester, api);

      await _tap(tester, find.text('13:00 – 14:00'));
      expect(find.text('No tables allocated yet.'), findsOneWidget);
      expect(find.text('0 Seats'), findsOneWidget);
    });

    testWidgets('a day without slots shows an empty message', (tester) async {
      await _pumpSection(tester, FakeApi());
      expect(find.text('No service slots for this day.'), findsOneWidget);
      expect(
        find.text('Select or create a slot to configure its tables.'),
        findsOneWidget,
      );
    });

    testWidgets('a server error is shown with Retry, which reloads the slots', (
      tester,
    ) async {
      final api = FakeApi()
        ..slotsError = const ApiException(
          500,
          'INTERNAL',
          'Database unavailable',
        );
      await _pumpSection(tester, api);
      expect(find.text('Database unavailable'), findsOneWidget);

      api
        ..slotsError = null
        ..slots = [_lunch()];
      await _tap(tester, find.text('Retry'));
      expect(find.text('12:00 – 13:00'), findsOneWidget);
      expect(api.called('listSlots'), hasLength(2));
    });

    testWidgets('changing the day reloads the slots of that day', (
      tester,
    ) async {
      final api = FakeApi();
      await _pumpSection(tester, api);

      final day = DateTime(_now.year + 1, 6, 15);
      await _changeDay(tester, day);
      expect(find.text(formatLongDate(day)), findsOneWidget);
      expect(api.called('listSlots').last.args['date'], formatYmd(day));
    });

    testWidgets('on a past day new slots cannot be added', (tester) async {
      final api = FakeApi();
      await _pumpSection(tester, api);

      await _changeDay(tester, DateTime(_now.year - 1, 6, 15));
      expect(
        find.text('Slots can only be added for today or future days.'),
        findsOneWidget,
      );
      final add = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Add Custom Service Slot'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(add.onPressed, isNull);
    });
  });

  group('Add a service slot', () {
    final future = DateTime(_now.year + 1, 6, 15);

    testWidgets(
      'creates the slot with start, end and an empty layout ("Define later")',
      (tester) async {
        final api = FakeApi();
        await _pumpSection(tester, api);
        await _changeDay(tester, future);

        await _tap(tester, find.text('Add Custom Service Slot'));
        await _pickTime(tester, 'Start time', 19, 0);
        await _pickTime(tester, 'End time', 20, 30);
        await _tap(tester, find.text('Create slot'));

        final call = api.called('createSlot').single;
        expect(call.args, {
          'startTime': '${formatYmd(future)} 19:00',
          'endTime': '${formatYmd(future)} 20:30',
          'tables': <Map<String, dynamic>>[],
          'copyFromTsId': null,
        });
        expect(find.text('Slot created.'), findsOneWidget);
      },
    );

    testWidgets('can copy the layout of a slot of the same day', (
      tester,
    ) async {
      final api = FakeApi()..slots = [_lunch(tsID: 5, day: future)];
      await _pumpSection(tester, api);
      await _changeDay(tester, future);

      await _tap(tester, find.text('Add Custom Service Slot'));
      await _pickTime(tester, 'Start time', 13, 0);
      await _pickTime(tester, 'End time', 14, 0);
      await _tap(tester, find.text('Define later'));
      await _tap(tester, find.text('Copy 12:00–13:00 (6 seats)').last);
      await _tap(tester, find.text('Create slot'));

      final call = api.called('createSlot').single;
      expect(call.args['copyFromTsId'], 5);
      expect(call.args['tables'], isNull);
    });

    testWidgets('without start and end time the slot is not created', (
      tester,
    ) async {
      final api = FakeApi();
      await _pumpSection(tester, api);

      await _tap(tester, find.text('Add Custom Service Slot'));
      await _tap(tester, find.text('Create slot'));
      expect(find.text('Select a start and an end time.'), findsOneWidget);
      expect(api.called('createSlot'), isEmpty);
    });

    testWidgets('the end time must be after the start time', (tester) async {
      final api = FakeApi();
      await _pumpSection(tester, api);
      await _changeDay(tester, future);

      await _tap(tester, find.text('Add Custom Service Slot'));
      await _pickTime(tester, 'Start time', 14, 0);
      await _pickTime(tester, 'End time', 13, 0);
      await _tap(tester, find.text('Create slot'));
      expect(find.text('End time must be after start time.'), findsOneWidget);
      expect(api.called('createSlot'), isEmpty);
    });

    testWidgets(
      'the server refusal (409 slot already exists) is shown to the employee',
      (tester) async {
        final api = FakeApi()
          ..createSlotError = const ApiException(
            409,
            'CONFLICT',
            'Slot already exists',
          );
        await _pumpSection(tester, api);
        await _changeDay(tester, future);

        await _tap(tester, find.text('Add Custom Service Slot'));
        await _pickTime(tester, 'Start time', 19, 0);
        await _pickTime(tester, 'End time', 20, 0);
        await _tap(tester, find.text('Create slot'));
        expect(find.text('Slot already exists'), findsOneWidget);
      },
    );
  });

  group('Configure the tables of a slot', () {
    staffTest('a slot without layout: add tables and save them', (
      tester,
    ) async {
      final api = FakeApi()..slots = [_emptySlot()];
      await _pumpSection(tester, api);

      await _tap(tester, find.text('Configure Slot Tables & Capacity'));
      await _tap(tester, find.text('Add Table'));
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '4');
      await _tap(tester, find.text('Insert'));
      await _tap(tester, find.text('Add Table'));
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '6');
      await _tap(tester, find.text('Insert'));
      expect(find.text('10 Total Seats'), findsOneWidget);

      await _tap(tester, find.text('Save Table Allocations'));
      final call = api.called('defineTables').single;
      expect(call.args['slotId'], 2);
      expect(call.args['tables'], [
        {'table_no': 1, 'seats': 4},
        {'table_no': 2, 'seats': 6},
      ]);
      expect(find.text('Table allocations saved.'), findsOneWidget);
    });

    staffTest(
      'a slot that already has a layout opens it read-only and saves nothing',
      (tester) async {
        final api = FakeApi()..slots = [_lunch()];
        await _pumpSection(tester, api);

        await _tap(tester, find.text('Configure Slot Tables & Capacity'));
        expect(find.textContaining('Layout already defined'), findsOneWidget);
        expect(find.text('Add Table'), findsNothing);
        expect(find.text('Save Table Allocations'), findsNothing);

        await _tap(tester, find.text('Close'));
        expect(api.called('defineTables'), isEmpty);
      },
    );

    staffTest('the server refusal is shown to the employee', (tester) async {
      final api = FakeApi()
        ..slots = [_emptySlot()]
        ..defineTablesError = const ApiException(
          409,
          'CONFLICT',
          'Layout already defined',
        );
      await _pumpSection(tester, api);

      await _tap(tester, find.text('Configure Slot Tables & Capacity'));
      await _tap(tester, find.text('Add Table'));
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '4');
      await _tap(tester, find.text('Insert'));
      await _tap(tester, find.text('Save Table Allocations'));
      expect(find.text('Layout already defined'), findsOneWidget);
    });
  });

  group('Table allocation modal', () {
    List<TableDraft>? saved;

    Future<void> openModal(
      WidgetTester tester, {
      List<TableDraft> tables = const [],
    }) async {
      saved = null;
      await pumpPage(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => saved = await showTableAllocationDialog(
                context,
                title: 'Tables',
                initialTables: tables,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
    }

    staffTest('lists the tables sorted by number with the total seats', (
      tester,
    ) async {
      await openModal(
        tester,
        tables: const [
          TableDraft(tableNo: 3, seats: 6),
          TableDraft(tableNo: 1, seats: 2),
        ],
      );

      expect(find.text('8 Total Seats'), findsOneWidget);
      expect(find.text('across 2 tables'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Table 01'));
      final second = tester.getTopLeft(find.text('Table 03'));
      expect(first.dy, lessThan(second.dy));
    });

    staffTest('a new table gets the next free number', (tester) async {
      await openModal(tester, tables: const [TableDraft(tableNo: 4, seats: 2)]);
      await _tap(tester, find.text('Add Table'));
      expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    });

    staffTest('seats must be a positive number', (tester) async {
      await openModal(tester);
      await _tap(tester, find.text('Add Table'));
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '0');
      await _tap(tester, find.text('Insert'));
      expect(
        find.text('Table # and seats must be positive numbers.'),
        findsOneWidget,
      );
    });

    staffTest('two tables cannot have the same number', (tester) async {
      await openModal(tester, tables: const [TableDraft(tableNo: 1, seats: 2)]);
      await _tap(tester, find.text('Add Table'));
      await tester.enterText(find.widgetWithText(TextField, 'Table #'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '4');
      await _tap(tester, find.text('Insert'));
      expect(find.text('Table 01 already exists.'), findsOneWidget);
    });

    staffTest('a table can be edited and deleted before saving', (
      tester,
    ) async {
      await openModal(
        tester,
        tables: const [
          TableDraft(tableNo: 1, seats: 2),
          TableDraft(tableNo: 2, seats: 4),
        ],
      );

      await _tap(tester, find.byTooltip('Edit table 01'));
      expect(find.text('EDITING TABLE 01'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Seats'), '3');
      await _tap(tester, find.text('Update'));
      await _tap(tester, find.byTooltip('Delete table 02'));
      await _tap(tester, find.text('Save Table Allocations'));

      expect(saved!.map((t) => t.toJson()), [
        {'table_no': 1, 'seats': 3},
      ]);
    });

    staffTest('an empty layout cannot be saved', (tester) async {
      await openModal(tester);
      await _tap(tester, find.text('Save Table Allocations'));
      expect(find.text('Add at least one table.'), findsOneWidget);
      expect(saved, isNull);
    });

    staffTest('Cancel closes the modal without returning tables', (
      tester,
    ) async {
      await openModal(tester, tables: const [TableDraft(tableNo: 1, seats: 2)]);
      await _tap(tester, find.text('Cancel'));
      expect(find.text('Save Table Allocations'), findsNothing);
      expect(saved, isNull);
    });
  });
}
