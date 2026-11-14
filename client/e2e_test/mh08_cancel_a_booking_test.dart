// MH-08 Cancel a booking — E2E (real app + real backend)
// As a hiker I can cancel a table booking, so that the hut can make the places
// available to other guests. Clarification: there are no time constraints.
import 'dart:math';

import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late int lunchId;
  late Hiker hiker;
  late Map<String, dynamic> booking;

  setUpAll(checkBackend);

  setUp(() async {
    day = await freshDay();
    // 6 seats in total: the hiker's party of 6 fills the slot
    lunchId = await createSlot(day, '12:00', '13:00', tablesOf([4, 2]));
    hiker = await newHiker();
    booking = await bookAs(hiker, lunchId, 6);
  });

  Finder cardOf(Map<String, dynamic> b) =>
      find.ancestor(of: find.text('REF  #${b['reference']}'), matching: find.byType(Card));

  Future<void> openMyBookings(WidgetTester tester, Hiker who, Map<String, dynamic> b) async {
    await launchApp(tester);
    await signInFromNavigation(tester, who.email);
    await tap(tester, find.text('My Bookings'));
    await waitFor(tester, find.text('REF  #${b['reference']}'));
  }

  Future<void> openCancelDialog(WidgetTester tester, Map<String, dynamic> b) async {
    await tap(tester, find.descendant(of: cardOf(b), matching: find.text('CANCEL BOOKING')));
    await waitFor(tester, find.text('Cancel Reservation?'));
  }

  Future<void> confirmCancellation(WidgetTester tester, Map<String, dynamic> b) async {
    await tap(tester, find.text('YES, CANCEL BOOKING'));
    await waitFor(tester, find.text('Your booking was successfully cancelled.'));
    await waitUntilGone(tester, find.text('REF  #${b['reference']}'));
  }

  Future<bool> available(int partySize) async =>
      (await MountainHutApi().checkAvailability(date: ymd(day), time: '12:00', partySize: partySize))['available']
          as bool;

  testWidgets('the hiker cancels a booking from My Bookings and it no longer exists on the server', (tester) async {
    await openMyBookings(tester, hiker, booking);
    await openCancelDialog(tester, booking);
    expect(find.textContaining('REF ${booking['reference']}'), findsOneWidget);
    await confirmCancellation(tester, booking);

    expect(await bookingsOf(hiker), isEmpty);
  });

  testWidgets('the released seats are offered to other guests again', (tester) async {
    expect(await available(1), isFalse); // the slot is full

    await openMyBookings(tester, hiker, booking);
    await openCancelDialog(tester, booking);
    await confirmCancellation(tester, booking);

    expect(await available(6), isTrue);
    final other = await newHiker('Other Hiker');
    final rebooked = await bookAs(other, lunchId, 6);
    expect(rebooked['n_people'], 6);
  });

  testWidgets('"Keep reservation" closes the dialog and the booking stays', (tester) async {
    await openMyBookings(tester, hiker, booking);
    await openCancelDialog(tester, booking);
    await tap(tester, find.text('KEEP RESERVATION'));
    await waitUntilGone(tester, find.text('Cancel Reservation?'));

    expect(find.text('REF  #${booking['reference']}'), findsOneWidget);
    expect((await bookingsOf(hiker)).single['bID'], booking['bID']);
  });

  testWidgets('less than 48 hours before the meal the booking is locked for changes but can be cancelled',
      (tester) async {
    // tomorrow, between 20:00 and 22:59: always less than 48 h but more than 2 h away
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final minute = Random().nextInt(180);
    final start = '${two(20 + minute ~/ 60)}:${two(minute % 60)}';
    final soonId = await createSlot(tomorrow, start, '23:59', tablesOf([4]));
    final soon = await bookAs(hiker, soonId, 2);

    await openMyBookings(tester, hiker, soon);
    expect(find.descendant(of: cardOf(soon), matching: find.text('MODIFICATION LOCKED')), findsOneWidget);
    await openCancelDialog(tester, soon);
    await confirmCancellation(tester, soon);

    final left = await bookingsOf(hiker);
    expect(left.map((b) => b['bID']), [booking['bID']]); // only the other booking is left
  });

  testWidgets('a hiker cancels a booking an employee made for them', (tester) async {
    final dinnerId = await createSlot(day, '19:00', '20:00', tablesOf([4]));
    final staffBooking = await asUser(staffEmail, (api) async {
      final found = await api.searchHikers(hiker.email);
      final uId = (found.single['uID'] as num).toInt();
      final res = await api.createStaffBooking(
        hiker: {'mode': 'existing', 'uID': uId},
        slotId: dinnerId,
        people: 2,
      );
      return res['booking'] as Map<String, dynamic>;
    });

    await openMyBookings(tester, hiker, staffBooking);
    await openCancelDialog(tester, staffBooking);
    await confirmCancellation(tester, staffBooking);

    final left = await bookingsOf(hiker);
    expect(left.map((b) => b['bID']), [booking['bID']]);
  });
}
