// MH-06 Change a booking — integration tests (My Bookings page + modify modal, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/hiker_portal/presentation/pages/my_bookings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeApi api;
  // Bookings are placed relative to the real clock, because the page uses DateTime.now()
  final now = DateTime.now();
  final nextWeek = DateTime(now.year, now.month, now.day + 7, 12);
  final tomorrow = now.add(const Duration(hours: 24));

  setUp(() {
    api = FakeApi()
      ..bookings = [
        bookingJson(start: nextWeek, requirements: [{'description': 'nut allergy', 'allergy': true}]),
      ]
      ..slots = [
        {'tsID': 3, 'start_time': slotTime(nextWeek), 'end_time': slotTime(nextWeek.add(const Duration(hours: 1)))},
        {'tsID': 4, 'start_time': slotTime(nextWeek.add(const Duration(hours: 7))), 'end_time': slotTime(nextWeek.add(const Duration(hours: 8)))},
      ];
  });

  Future<void> open(WidgetTester tester) => pumpPage(tester, MyBookingsPage(api: api));

  Future<void> openModifyModal(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('EDIT / CHANGE BOOKING'));
    await tester.pumpAndSettle();
  }

  // The modal triggers a known Flutter debug assertion (see the [BUG] test below).
  // The other modal tests ignore only that message, so they still check the behaviour.
  const listTileAssertion = 'ListTile background color or ink splashes may be invisible';

  Future<void> ignoringListTileAssertion(Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains(listTileAssertion)) original?.call(details);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = original;
    }
  }

  void modalTest(String description, Future<void> Function(WidgetTester tester) body) =>
      testWidgets(description, (tester) => ignoringListTileAssertion(() => body(tester)));

  Future<void> tapInModal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('My Bookings list', () {
    testWidgets('shows reference, party size, tables and requirements of each booking', (tester) async {
      await open(tester);
      expect(find.text('REF  #MH-7'), findsOneWidget);
      expect(find.textContaining('4 Guests'), findsOneWidget);
      expect(find.textContaining('Table 2'), findsOneWidget);
      expect(find.text('nut allergy (Allergy Flag)'), findsOneWidget);
    });

    testWidgets('a booking more than 48 hours away can be changed', (tester) async {
      await open(tester);
      expect(find.text('EDIT / CHANGE BOOKING'), findsOneWidget);
      expect(find.text('MODIFICATION LOCKED'), findsNothing);
    });

    testWidgets('a booking less than 48 hours away is locked', (tester) async {
      api.bookings = [bookingJson(start: tomorrow)];
      await open(tester);
      expect(find.text('MODIFICATION LOCKED'), findsOneWidget);
      expect(find.text('EDIT / CHANGE BOOKING'), findsNothing);
    });

    testWidgets('says when there are no bookings', (tester) async {
      api.bookings = [];
      await open(tester);
      expect(find.text('You have no upcoming reservations.'), findsOneWidget);
    });

    testWidgets('a loading error can be retried', (tester) async {
      api.bookingsError = const ApiException(401, 'UNAUTHENTICATED', 'Login required');
      await open(tester);
      expect(find.text('Login required'), findsOneWidget);

      api.bookingsError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('REF  #MH-7'), findsOneWidget);
    });
  });

  group('Modify reservation', () {
    // [BUG] The modal puts ListTile / CheckboxListTile inside a coloured Container with
    // no Material in between, so Flutter raises "ListTile background color or ink
    // splashes may be invisible" every time the modal opens in debug mode. Wrapping the
    // sheet content in a Material (or using its color) fixes it. Fails until fixed.
    testWidgets('[BUG] the modal opens without Flutter framework errors', (tester) async {
      await openModifyModal(tester);
      expect(tester.takeException(), isNull);
    });

    modalTest('opens on the booking with its current slots for that date', (tester) async {
      await openModifyModal(tester);
      expect(find.text('MODIFY RESERVATION'), findsOneWidget);
      expect(find.text('Booking MH-7'), findsOneWidget);
      expect(api.called('listSlots').single.args['date'], slotTime(nextWeek).substring(0, 10));
    });

    modalTest('changing the party size saves it and reloads the list', (tester) async {
      await openModifyModal(tester);
      await tapInModal(tester, find.widgetWithIcon(IconButton, Icons.add));
      await tapInModal(tester, find.text('SAVE CHANGES'));

      expect(api.called('updateBooking').single.args, {
        'id': 7,
        'slotId': 3,
        'people': 5,
        'requirements': [{'description': 'nut allergy', 'allergy': true}],
      });
      expect(find.text('MODIFY RESERVATION'), findsNothing);
      expect(api.called('myBookings'), hasLength(2));
    });

    modalTest('a new allergy requirement is sent with its flag', (tester) async {
      await openModifyModal(tester);
      await tester.enterText(find.byType(TextField), 'shellfish');
      await tapInModal(tester, find.byType(CheckboxListTile));
      await tapInModal(tester, find.text('ADD DIETARY / ALLERGY REQUIREMENT'));
      await tapInModal(tester, find.text('SAVE CHANGES'));

      expect(api.called('updateBooking').single.args['requirements'], [
        {'description': 'nut allergy', 'allergy': true},
        {'description': 'shellfish', 'allergy': true},
      ]);
    });

    modalTest('an existing requirement can be removed', (tester) async {
      await openModifyModal(tester);
      await tapInModal(tester, find.byTooltip('Remove requirement'));
      await tapInModal(tester, find.text('SAVE CHANGES'));
      expect(api.called('updateBooking').single.args['requirements'], isEmpty);
    });

    modalTest('an empty requirement is not added', (tester) async {
      await openModifyModal(tester);
      await tapInModal(tester, find.text('ADD DIETARY / ALLERGY REQUIREMENT'));
      expect(find.text('Enter a dietary or allergy requirement first.'), findsOneWidget);
    });

    modalTest('a change refused by the server (409) is shown and the modal stays open', (tester) async {
      api.updateError = const ApiException(409, 'CONFLICT', 'Not enough free seats');
      await openModifyModal(tester);
      await tapInModal(tester, find.text('SAVE CHANGES'));

      expect(find.text('Not enough free seats'), findsOneWidget);
      expect(find.text('MODIFY RESERVATION'), findsOneWidget);
    });
  });
}
