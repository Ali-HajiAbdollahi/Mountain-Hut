// MH-20 Register a hike — integration tests (ExplorePage + HikeRegistrationPage, fake API)
import 'dart:async';

import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/explore/presentation/pages/explore_page.dart';
import 'package:client/features/hike_registration/presentation/pages/hike_registration_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _button = 'Register a Planned Hike';
const _hikesTab = 'Hikes';
const _destinationHint = 'e.g. Monte Viso Base';
const _routeHint = 'e.g. via the Chiaretto lake';
const _pointHint = 'e.g. Colle del Pas';

String _two(int n) => n.toString().padLeft(2, '0');
String _shown(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
String _sent(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi()..slots = [];
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) => pumpPage(tester, HikeRegistrationPage(api: api));

  Future<void> fillRequired(WidgetTester tester, {String destination = 'Chiaretto Lake'}) async {
    await tester.enterText(find.widgetWithText(TextFormField, _destinationHint), destination);
    await tester.enterText(find.widgetWithText(TextFormField, _routeHint), 'via the east ridge');
    await tester.pump();
  }

  Future<void> pick(WidgetTester tester, String section, DateTime when) async {
    final field = find.ancestor(of: find.byIcon(Icons.schedule), matching: find.byType(InkWell));
    await tap(tester, field.at(section == 'DEPARTURE TIME' ? 0 : 1));
    await tap(tester, find.byIcon(Icons.edit_outlined));
    await tester.enterText(find.byType(TextField).last, '${_two(when.month)}/${_two(when.day)}/${when.year}');
    await tap(tester, find.text('OK'));
    await tap(tester, find.byIcon(Icons.keyboard_outlined));
    final inputs = find.descendant(of: find.byType(Dialog).last, matching: find.byType(TextField));
    await tester.enterText(inputs.at(0), _two(when.hour));
    await tester.enterText(inputs.at(1), _two(when.minute));
    await tap(tester, find.text('OK'));
  }

  Map<String, dynamic> sentHike() => api.called('registerHike').single.args['hike']! as Map<String, dynamic>;

  group('Opening the form from Explore', () {
    testWidgets('the button is in the "Hikes" tab, not in the table search', (tester) async {
      api.user = {'uID': 2, 'role': 'hiker', 'name': 'Marco Bianchi'};
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));

      expect(find.text(_button), findsNothing);
      await tap(tester, find.text(_hikesTab));
      expect(find.text(_button), findsOneWidget);
      expect(find.text('My Hikes'), findsOneWidget);
    });

    testWidgets('a signed-in hiker sees "Register a Planned Hike" and it opens the form', (tester) async {
      api.user = {'uID': 2, 'role': 'hiker', 'name': 'Marco Bianchi'};
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));
      await tap(tester, find.text(_hikesTab));

      expect(find.text(_button), findsOneWidget);
      await tap(tester, find.text(_button));
      expect(find.byType(HikeRegistrationPage), findsOneWidget);
      expect(find.text('Register a Hike'), findsOneWidget);
    });

    testWidgets('a visitor without login does not see the button but is asked to sign in', (tester) async {
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));
      await tap(tester, find.text(_hikesTab));
      expect(find.text(_button), findsNothing);
      expect(find.text('Sign in to register a hike'), findsOneWidget);
      expect(find.text('My Hikes'), findsNothing);
    });

    testWidgets('an employee does not see the button', (tester) async {
      api.user = {'uID': 9, 'role': 'employee', 'name': 'Elena Gestore'};
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));
      await tap(tester, find.text(_hikesTab));
      expect(find.text(_button), findsNothing);
    });
  });

  group('The form', () {
    testWidgets('asks for destination, route, passage points, departure and expected return', (tester) async {
      await openForm(tester);

      for (final label in [
        'DESTINATION',
        'ROUTE DESCRIPTION',
        'INTERMEDIATE PASSAGE POINTS',
        'DEPARTURE TIME',
        'EXPECTED RETURN TIME',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('PARTY SIZE'), findsNothing);
      expect(find.text('HIKER PHONE'), findsNothing);
      expect(find.textContaining('EMERGENCY CONTACT'), findsNothing);
    });

    testWidgets('by default the departure is in about an hour and the return four hours later', (tester) async {
      final before = DateTime.now();
      await openForm(tester);
      final shown = RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}$');
      final times = tester.widgetList<Text>(find.byWidgetPredicate(
              (w) => w is Text && w.data != null && shown.hasMatch(w.data!)))
          .map((t) => t.data!)
          .toList();

      expect(times, hasLength(2));
      final departure = before.add(const Duration(hours: 1));
      expect(times[0], anyOf(_shown(departure), _shown(departure.add(const Duration(minutes: 1)))));
    });

    testWidgets('destination and route are required: nothing is sent without them', (tester) async {
      await openForm(tester);
      await tap(tester, find.text('Register Hike'));

      expect(find.text('Destination is required'), findsOneWidget);
      expect(find.text('Route description is required'), findsOneWidget);
      expect(api.called('registerHike'), isEmpty);
    });

    testWidgets('blank destination and route are not accepted', (tester) async {
      await openForm(tester);
      await fillRequired(tester, destination: '   ');
      await tester.enterText(find.widgetWithText(TextFormField, _routeHint), '  ');
      await tap(tester, find.text('Register Hike'));

      expect(find.text('Destination is required'), findsOneWidget);
      expect(api.called('registerHike'), isEmpty);
    });
  });

  group('Passage points', () {
    testWidgets('several points can be added and are sent in order', (tester) async {
      await openForm(tester);
      await fillRequired(tester);
      await tester.enterText(find.widgetWithText(TextField, _pointHint).at(0), 'Old Bridge');
      await tap(tester, find.text('Add Passage Point'));
      await tester.enterText(find.widgetWithText(TextField, _pointHint).at(1), 'Vizo Mozzo');
      await tester.pump();
      await tap(tester, find.text('Register Hike'));

      expect(sentHike()['waypoints'], [{'name': 'Old Bridge'}, {'name': 'Vizo Mozzo'}]);
    });

    testWidgets('a point can be removed', (tester) async {
      await openForm(tester);
      await fillRequired(tester);
      await tester.enterText(find.widgetWithText(TextField, _pointHint).at(0), 'Old Bridge');
      await tap(tester, find.text('Add Passage Point'));
      await tester.enterText(find.widgetWithText(TextField, _pointHint).at(1), 'Vizo Mozzo');
      await tester.pump();
      await tap(tester, find.byTooltip('Remove point').first);
      await tap(tester, find.text('Register Hike'));

      expect(sentHike()['waypoints'], [{'name': 'Vizo Mozzo'}]);
    });

    testWidgets('passage points are optional: empty rows are not sent', (tester) async {
      await openForm(tester);
      await fillRequired(tester);
      await tap(tester, find.text('Add Passage Point'));
      await tap(tester, find.text('Register Hike'));

      expect(sentHike()['waypoints'], isEmpty);
    });
  });

  group('Departure and expected return', () {
    testWidgets('the chosen times are shown and sent to the server', (tester) async {
      final now = DateTime.now();
      final departure = DateTime(now.year, now.month, now.day + 2, 8, 30);
      final back = DateTime(now.year, now.month, now.day + 2, 16, 45);
      await openForm(tester);
      await fillRequired(tester);
      await pick(tester, 'DEPARTURE TIME', departure);
      await pick(tester, 'EXPECTED RETURN TIME', back);

      expect(find.text(_shown(departure)), findsOneWidget);
      expect(find.text(_shown(back)), findsOneWidget);
      await tap(tester, find.text('Register Hike'));
      expect(sentHike()['departure_time'], _sent(departure));
      expect(sentHike()['expected_return'], _sent(back));
    });

    testWidgets('a departure after the return moves the return four hours after the departure', (tester) async {
      final now = DateTime.now();
      final departure = DateTime(now.year, now.month, now.day + 3, 9, 0);
      await openForm(tester);
      await pick(tester, 'DEPARTURE TIME', departure);

      expect(find.text(_shown(departure.add(const Duration(hours: 4)))), findsOneWidget);
    });

    testWidgets('a return before the departure is refused before sending', (tester) async {
      final now = DateTime.now();
      final departure = DateTime(now.year, now.month, now.day + 2, 12, 0);
      await openForm(tester);
      await fillRequired(tester);
      await pick(tester, 'DEPARTURE TIME', departure);
      await pick(tester, 'EXPECTED RETURN TIME', DateTime(departure.year, departure.month, departure.day, 10, 0));
      await tap(tester, find.text('Register Hike'));

      expect(find.text('Expected return must be after departure time.'), findsOneWidget);
      expect(api.called('registerHike'), isEmpty);
    });
  });

  group('Sending the registration', () {
    testWidgets('sends only the fields the server stores and shows the confirmation', (tester) async {
      await openForm(tester);
      await fillRequired(tester);
      await tap(tester, find.text('Register Hike'));

      expect(sentHike().keys.toSet(), {'destination', 'route', 'departure_time', 'expected_return', 'waypoints'});
      expect(sentHike()['destination'], 'Chiaretto Lake');
      expect(sentHike()['route'], 'via the east ridge');
      expect(find.text('Hike Registered'), findsOneWidget);
      expect(find.text('Your planned hike to Chiaretto Lake has been recorded. Stay safe on the trail!'),
          findsOneWidget);
    });

    testWidgets('"Back to Explore" closes the page after the registration', (tester) async {
      api.user = {'uID': 2, 'role': 'hiker', 'name': 'Marco Bianchi'};
      await pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));
      await tap(tester, find.text(_hikesTab));
      await tap(tester, find.text(_button));
      await fillRequired(tester);
      await tap(tester, find.text('Register Hike'));
      await tap(tester, find.text('Back to Explore'));

      expect(find.byType(HikeRegistrationPage), findsNothing);
      expect(find.text(_button), findsOneWidget);
    });

    testWidgets('while sending, the button is disabled and says "Registering…"', (tester) async {
      api.registerHikeGate = Completer<void>();
      await openForm(tester);
      await fillRequired(tester);
      await tester.ensureVisible(find.text('Register Hike'));
      await tester.tap(find.text('Register Hike'));
      await tester.pump();

      expect(find.text('Registering…'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
          find.ancestor(of: find.text('Registering…'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(button.onPressed, isNull);

      api.registerHikeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Hike Registered'), findsOneWidget);
    });

    testWidgets('a refusal of the server is shown and the form stays open', (tester) async {
      api.registerHikeError = const ApiException(400, 'VALIDATION_ERROR', 'departure_time cannot be in the past');
      await openForm(tester);
      await fillRequired(tester);
      await tap(tester, find.text('Register Hike'));

      expect(find.text('departure_time cannot be in the past'), findsOneWidget);
      expect(find.text('Hike Registered'), findsNothing);
      expect(find.text('Register Hike'), findsOneWidget);
    });

    testWidgets('when the server cannot be reached, a generic message is shown', (tester) async {
      api.registerHikeError = Exception('connection refused');
      await openForm(tester);
      await fillRequired(tester);
      await tap(tester, find.text('Register Hike'));

      expect(find.text('Could not reach the server. Try again.'), findsOneWidget);
    });
  });
}
