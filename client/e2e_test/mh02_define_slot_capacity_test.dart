// MH-02 Define slot capacity — E2E (real app + real backend)
// As an employee I can create the meal slots of a day and define their tables
// (or reuse a previous layout), so that the capacity is known.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;

  setUpAll(checkBackend);

  setUp(() async => day = await freshDay());

  /// Signs in as the seeded employee, opens the staff portal and selects [target].
  Future<void> openStaffPortalOn(WidgetTester tester, DateTime target) async {
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Staff Portal'));
    await waitFor(tester, find.text('SERVICE SLOTS'));
    await tap(tester, find.text('Change'));
    await typeInDatePicker(tester, target);
    await waitUntilGone(tester, find.byType(CircularProgressIndicator));
  }

  Future<void> pickTime(WidgetTester tester, String field, int hour, int minute) async {
    await tap(tester, find.ancestor(of: find.text(field), matching: find.byType(InkWell)));
    await typeInTimePicker(tester, hour, minute);
  }

  Future<void> addSlot(WidgetTester tester, int startHour, int endHour) async {
    await tap(tester, find.text('Add Custom Service Slot'));
    await pickTime(tester, 'Start time', startHour, 0);
    await pickTime(tester, 'End time', endHour, 0);
    await tap(tester, find.text('Create slot'));
    await waitFor(tester, find.text('Slot created.'));
  }

  Future<void> addTable(WidgetTester tester, int seats) async {
    await tap(tester, find.text('Add Table'));
    await type(tester, find.widgetWithText(TextField, 'Seats'), '$seats');
    await tap(tester, find.text('Insert'));
  }

  testWidgets('the employee creates a slot and defines its tables: the capacity is stored', (tester) async {
    await openStaffPortalOn(tester, day);
    await addSlot(tester, 12, 13);

    await tap(tester, find.text('Configure Slot Tables & Capacity'));
    await addTable(tester, 4);
    await addTable(tester, 6);
    expect(find.text('10 Total Seats'), findsOneWidget);
    await tap(tester, find.text('Save Table Allocations'));
    await waitFor(tester, find.text('Table allocations saved.'));
    expect(find.text('10 Seats'), findsOneWidget);

    final slot = (await slotsOn(day)).single;
    expect(slot['start_time'], '${ymd(day)} 12:00');
    expect(slot['end_time'], '${ymd(day)} 13:00');
    expect(slot['capacity'], 10);
  });

  testWidgets('a new slot can reuse the layout of the preceding slot', (tester) async {
    await createSlot(day, '12:00', '13:00', tablesOf([2, 4]));

    await openStaffPortalOn(tester, day);
    await addSlot(tester, 13, 14);
    await tap(tester, find.text('Reuse Layout'));
    await waitFor(tester, find.text('Layout copied.'));

    final second = (await slotsOn(day)).singleWhere((s) => s['start_time'] == '${ymd(day)} 13:00');
    expect(second['capacity'], 6);
  });

  testWidgets('a slot defined by the employee is offered to visitors', (tester) async {
    await openStaffPortalOn(tester, day);
    await addSlot(tester, 19, 20);
    await tap(tester, find.text('Configure Slot Tables & Capacity'));
    await addTable(tester, 4);
    await tap(tester, find.text('Save Table Allocations'));
    await waitFor(tester, find.text('Table allocations saved.'));

    // a visitor, in a new session, checks availability on that day
    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await setGuests(tester, 4);
    await checkAvailability(tester);
    expect(find.text('Proceed to Reservation'), findsOneWidget);
  });

  testWidgets('a saved layout is read-only', (tester) async {
    await createSlot(day, '12:00', '13:00', tablesOf([4]));

    await openStaffPortalOn(tester, day);
    await tap(tester, find.text('Configure Slot Tables & Capacity'));
    expect(find.textContaining('Layout already defined'), findsOneWidget);
    expect(find.text('Save Table Allocations'), findsNothing);
  });

  testWidgets('a hiker cannot reach the staff portal', (tester) async {
    final hiker = await newHiker();
    await launchApp(tester);
    await signInFromNavigation(tester, hiker.email);
    await waitFor(tester, find.text('My Bookings'));

    expect(find.text('Staff Portal'), findsNothing);
  });
}
