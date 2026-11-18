// MH-20 Register a hike + MH-21 View active hikes — E2E (real app + real backend)
// MH-20: as a hiker I can register my planned hike before departure, so that the hut has
// information that can be used if I do not return as expected.
// MH-21: as an employee I can see all hikers currently on a hike, so that I can monitor
// their expected return times.
//
// A hike is active only once its departure time has passed, and the server refuses
// departures in the past. All hikes therefore start at the same time T0, a few minutes
// after the start of the file, and the tests wait for T0 once. The tests run in order:
// the hike registered from the form in the first test is checked by the staff in the second.
// There is no way to record a return yet (MH-22), so hikes stay active: each test looks
// for its own hikes by their unique destination and never counts the whole list.
import 'dart:math';

import 'package:client/features/staff_portal/presentation/widgets/active_hikes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

final _tag = Random().nextInt(1 << 20).toRadixString(36);
final _formHike = 'Form Lake $_tag';
final _apiHike = 'Ridge Peak $_tag';
final _otherHike = 'Ridge Peak $_tag (second hiker)';
final _overdueHike = 'Late Pass $_tag';
final _futureHike = 'Tomorrow Col $_tag';

String _at(DateTime t) => '${ymd(t)} ${two(t.hour)}:${two(t.minute)}';

Future<void> _registerAs(Hiker hiker, Map<String, dynamic> hike) =>
    asUser(hiker.email, (api) => api.registerHike(hike));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime t0;
  late Hiker marco;
  late Hiker sara;

  setUpAll(() async {
    await checkBackend();
    final now = DateTime.now();
    t0 = DateTime(now.year, now.month, now.day, now.hour, now.minute + 3);
    marco = await newHiker('Marco $_tag');
    sara = await newHiker('Sara $_tag');

    await _registerAs(marco, {
      'destination': _apiHike,
      'route': 'via the east ridge',
      'departure_time': _at(t0),
      'expected_return': _at(t0.add(const Duration(hours: 6))),
      'waypoints': [{'name': 'Old Bridge'}, {'name': 'Vizo Mozzo'}],
    });
    await _registerAs(sara, {
      'destination': _otherHike,
      'route': 'via the lake',
      'departure_time': _at(t0),
      'expected_return': _at(t0.add(const Duration(hours: 5))),
    });
    await _registerAs(sara, {
      'destination': _overdueHike,
      'route': 'short loop',
      'departure_time': _at(t0),
      'expected_return': _at(t0.add(const Duration(minutes: 1))),
    });
    await _registerAs(marco, {
      'destination': _futureHike,
      'route': 'tomorrow morning',
      'departure_time': _at(t0.add(const Duration(days: 1))),
      'expected_return': _at(t0.add(const Duration(days: 1, hours: 4))),
    });
  });

  /// Keeps the app running until [moment] (plus a few seconds of margin) has passed.
  /// Real one-second pauses leave the browser free while waiting.
  Future<void> waitUntil(WidgetTester tester, DateTime moment) async {
    final end = moment.add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    }
  }

  /// Waits, with real pauses, until [finder] is on screen (e.g. after the automatic refresh).
  Future<void> waitForShown(WidgetTester tester, Finder finder, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) fail('Timed out waiting for: $finder\n${describeScreen()}');
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openActiveHikes(WidgetTester tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Staff Portal'));
    await tap(tester, find.text('Active Hikes'));
    await waitUntilGone(tester, find.byType(CircularProgressIndicator));
  }

  Finder inList(Finder finder) => find.descendant(of: find.byType(ActiveHikesSection), matching: finder);

  /// The card of the hike to [destination], scrolled into view.
  Future<Finder> cardOf(WidgetTester tester, String destination) async {
    await tester.scrollUntilVisible(
      inList(find.text(destination)),
      300,
      scrollable: inList(find.byType(Scrollable)).first,
    );
    return find.ancestor(of: inList(find.text(destination)), matching: find.byType(Card));
  }

  bool shows(Finder card, String text) => find.descendant(of: card, matching: find.text(text)).evaluate().isNotEmpty;

  testWidgets('MH-20: a hiker registers a planned hike from Explore', (tester) async {
    await launchApp(tester);
    await signInFromNavigation(tester, marco.email);
    await tap(tester, find.text('Register a Planned Hike'));
    await waitFor(tester, find.text('Register a Hike'));

    await type(tester, fieldWithHint('e.g. Monte Viso Base'), _formHike);
    await type(tester, fieldWithHint('e.g. via the Chiaretto lake'), 'via the Chiaretto lake');
    await type(tester, find.widgetWithText(TextField, 'e.g. Colle del Pas'), 'Colle del Pas');
    await tap(tester, find.ancestor(of: find.byIcon(Icons.schedule), matching: find.byType(InkWell)).first);
    await typeInDatePicker(tester, t0);
    await typeInTimePicker(tester, t0.hour, t0.minute);
    expect(DateTime.now().isBefore(t0), isTrue, reason: 'the form must be sent before the departure time');

    await tap(tester, find.text('Register Hike'));
    await waitFor(tester, find.text('Hike Registered'));
    expect(find.text('Your planned hike to $_formHike has been recorded. Stay safe on the trail!'), findsOneWidget);
  });

  testWidgets('MH-20 + MH-21: before departure the staff do not see the hike, then it appears by itself',
      (tester) async {
    await openActiveHikes(tester);
    expect(DateTime.now().isBefore(t0), isTrue, reason: 'the list must be opened before the departure time');
    for (final destination in [_formHike, _apiHike, _otherHike]) {
      expect(inList(find.text(destination)), findsNothing, reason: destination);
    }

    await waitUntil(tester, t0);
    await waitForShown(tester, inList(find.text(_formHike)), const Duration(seconds: 45));

    final card = await cardOf(tester, _formHike);
    expect(shows(card, 'Marco $_tag'), isTrue);
    expect(shows(card, 'via the Chiaretto lake'), isTrue);
    expect(shows(card, '1. Colle del Pas'), isTrue);
  });

  testWidgets('MH-21: each active hike shows hiker, destination, route, expected return and waypoints',
      (tester) async {
    await waitUntil(tester, t0);
    await openActiveHikes(tester);

    final marcoCard = await cardOf(tester, _apiHike);
    for (final text in ['Marco $_tag', 'via the east ridge', _at(t0.add(const Duration(hours: 6))),
        'WAYPOINTS', '1. Old Bridge', '2. Vizo Mozzo']) {
      expect(shows(marcoCard, text), isTrue, reason: text);
    }

    final saraCard = await cardOf(tester, _otherHike);
    expect(shows(saraCard, 'Sara $_tag'), isTrue);
    expect(shows(saraCard, 'via the lake'), isTrue);
    expect(shows(saraCard, 'WAYPOINTS'), isFalse);
  });

  testWidgets('MH-21: a hike whose expected return has passed is still shown', (tester) async {
    await waitUntil(tester, t0.add(const Duration(minutes: 1)));
    await openActiveHikes(tester);

    final card = await cardOf(tester, _overdueHike);
    expect(shows(card, 'Sara $_tag'), isTrue);
    expect(shows(card, _at(t0.add(const Duration(minutes: 1)))), isTrue);
  });

  testWidgets('MH-21: a hike that starts tomorrow is not shown, and is not active on the server', (tester) async {
    await waitUntil(tester, t0);
    await openActiveHikes(tester);
    await cardOf(tester, _apiHike);

    expect(inList(find.text(_futureHike)), findsNothing);
    final active = await asUser(staffEmail, (api) => api.listActiveHikes());
    expect(active.map((h) => h['destination']), isNot(contains(_futureHike)));
    expect(active.map((h) => h['destination']), containsAll([_formHike, _apiHike, _otherHike, _overdueHike]));
  });
}
