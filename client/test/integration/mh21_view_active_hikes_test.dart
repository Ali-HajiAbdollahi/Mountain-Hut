// MH-21 View active hikes — integration tests (ActiveHikesPage + ActiveHikesSection, fake API)
import 'dart:async';

import 'package:client/core/navigation/app_bottom_navigation.dart';
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/staff_portal/presentation/pages/active_hikes_page.dart';
import 'package:client/features/staff_portal/presentation/widgets/active_hikes_section.dart';
import 'package:client/features/staff_portal/presentation/widgets/staff_portal_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Map<String, dynamic> _hike({
  int hID = 1,
  String hiker = 'Marco Bianchi',
  String destination = 'Chiaretto Lake',
  String? route = 'via the east ridge',
  String expectedReturn = '2026-12-01 17:30',
  List<String> waypoints = const ['Old Bridge', 'Vizo Mozzo'],
}) =>
    {
      'hID': hID,
      'hiker_name': hiker,
      'destination': destination,
      'route': route,
      'expected_return': expectedReturn,
      'waypoints': [
        for (var i = 0; i < waypoints.length; i++) {'position': i + 1, 'name': waypoints[i]},
      ],
    };

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi()..slots = [];
  });

  Future<void> open(WidgetTester tester) =>
      pumpPage(tester, Scaffold(body: ActiveHikesSection(api: api)));

  Finder cardOf(String hiker) => find.ancestor(of: find.text(hiker), matching: find.byType(Card));

  bool cardShows(WidgetTester tester, String hiker, String text) =>
      find.descendant(of: cardOf(hiker), matching: find.text(text)).evaluate().isNotEmpty;

  group('In the staff area', () {
    testWidgets('the active hikes have their own page, next to Dining in the bottom navigation',
        (tester) async {
      api.activeHikes = [_hike()];
      await pumpPage(tester, ActiveHikesPage(authRepository: FakeAuthRepository(), api: api));

      expect(find.text('ACTIVE HIKES'), findsOneWidget);
      expect(find.text('1 active hike'), findsOneWidget);
      expect(find.text('Marco Bianchi'), findsOneWidget);
      expect(api.called('listActiveHikes'), isNotEmpty);
      for (final item in ['Dining', 'Active Hikes', 'Account']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('the Dining area keeps only the dining tabs', (tester) async {
      await pumpPage(tester, Scaffold(body: StaffPortalBody(api: api)));

      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Phone / Walk-in Booking'), findsOneWidget);
      expect(find.text('Active Hikes'), findsNothing);
      expect(find.byType(ActiveHikesSection), findsNothing);
      expect(api.called('listActiveHikes'), isEmpty);
    });

    testWidgets('an employee reaches the active hikes from the bottom navigation', (tester) async {
      var opened = 0;
      await pumpPage(
        tester,
        Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            role: AppNavigationRole.employee,
            selectedTab: AppNavigationTab.staffPortal,
            onActiveHikes: () => opened++,
          ),
        ),
      );

      await tester.tap(find.text('Active Hikes'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });

  group('The list of active hikes', () {
    testWidgets('shows hiker, destination, route, expected return and waypoints of each hike', (tester) async {
      api.activeHikes = [_hike()];
      await open(tester);

      for (final text in ['Destination', 'Chiaretto Lake', 'Route', 'via the east ridge', 'Expected return',
          '2026-12-01 17:30', 'WAYPOINTS', '1. Old Bridge', '2. Vizo Mozzo']) {
        expect(cardShows(tester, 'Marco Bianchi', text), isTrue, reason: text);
      }
    });

    testWidgets('shows one card per hike, in the order of the server, and counts them', (tester) async {
      api.activeHikes = [
        _hike(hID: 5, hiker: 'Sara Verdi', expectedReturn: '2026-12-01 11:00'),
        _hike(hID: 3, hiker: 'Marco Bianchi', expectedReturn: '2026-12-01 17:30'),
      ];
      await open(tester);

      expect(find.text('2 active hikes'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      final sara = tester.getTopLeft(find.text('Sara Verdi')).dy;
      final marco = tester.getTopLeft(find.text('Marco Bianchi')).dy;
      expect(sara, lessThan(marco));
    });

    testWidgets('two hikers with the same destination are shown separately', (tester) async {
      api.activeHikes = [_hike(hID: 1, hiker: 'Marco Bianchi'), _hike(hID: 2, hiker: 'Sara Verdi')];
      await open(tester);

      expect(find.text('Chiaretto Lake'), findsNWidgets(2));
      expect(cardShows(tester, 'Marco Bianchi', 'Chiaretto Lake'), isTrue);
      expect(cardShows(tester, 'Sara Verdi', 'Chiaretto Lake'), isTrue);
    });

    testWidgets('a hike without route or waypoints hides those rows', (tester) async {
      api.activeHikes = [_hike(route: '', waypoints: [])];
      await open(tester);

      expect(cardShows(tester, 'Marco Bianchi', 'Route'), isFalse);
      expect(cardShows(tester, 'Marco Bianchi', 'WAYPOINTS'), isFalse);
      expect(cardShows(tester, 'Marco Bianchi', 'Chiaretto Lake'), isTrue);
    });

    testWidgets('a missing hiker name is shown as "Unknown hiker"', (tester) async {
      api.activeHikes = [{..._hike(), 'hiker_name': null}];
      await open(tester);
      expect(find.text('Unknown hiker'), findsOneWidget);
    });

    testWidgets('when nobody is out, it says so', (tester) async {
      await open(tester);
      expect(find.text('No active hikes'), findsOneWidget);
      expect(find.text('Active hikes will appear here when hikers depart.'), findsOneWidget);
    });

    testWidgets('a loading indicator is shown until the hikes arrive', (tester) async {
      api.activeHikesGate = Completer<void>();
      api.activeHikes = [_hike()];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ActiveHikesSection(api: api))));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      api.activeHikesGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Marco Bianchi'), findsOneWidget);
    });
  });

  group('Errors', () {
    testWidgets('a server error is shown with "Retry", which loads the hikes again', (tester) async {
      api.activeHikesError = const ApiException(503, 'DATABASE_BUSY', 'Please retry shortly');
      await open(tester);
      expect(find.text('Please retry shortly'), findsOneWidget);

      api
        ..activeHikesError = null
        ..activeHikes = [_hike()];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Marco Bianchi'), findsOneWidget);
      expect(api.called('listActiveHikes'), hasLength(2));
    });

    testWidgets('a hiker who opens it is refused with the server message', (tester) async {
      api.activeHikesError = const ApiException(403, 'FORBIDDEN', 'Operation not allowed');
      await open(tester);
      expect(find.text('Operation not allowed'), findsOneWidget);
    });

    testWidgets('when the server cannot be reached, a generic message is shown', (tester) async {
      api.activeHikesError = Exception('connection refused');
      await open(tester);
      expect(find.text('Unable to load active hikes.'), findsOneWidget);
    });
  });

  group('Monitoring the expected returns', () {
    testWidgets('the list refreshes by itself every 30 seconds', (tester) async {
      await open(tester);
      expect(find.text('No active hikes'), findsOneWidget);

      api.activeHikes = [_hike(hiker: 'Sara Verdi')];
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('Sara Verdi'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Sara Verdi'), findsOneWidget);
      expect(api.called('listActiveHikes'), hasLength(2));
    });

    testWidgets('a hike that is back disappears at the next refresh', (tester) async {
      api.activeHikes = [_hike(hID: 1, hiker: 'Marco Bianchi'), _hike(hID: 2, hiker: 'Sara Verdi')];
      await open(tester);

      api.activeHikes = [_hike(hID: 2, hiker: 'Sara Verdi')];
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Marco Bianchi'), findsNothing);
      expect(find.text('1 active hike'), findsOneWidget);
    });

    testWidgets('if a refresh fails, the hikes already shown stay on screen', (tester) async {
      api.activeHikes = [_hike()];
      await open(tester);

      api.activeHikesError = const ApiException(503, 'DATABASE_BUSY', 'Please retry shortly');
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Marco Bianchi'), findsOneWidget);
      expect(find.text('Please retry shortly'), findsNothing);
    });

    testWidgets('the list can also be refreshed by pulling it down', (tester) async {
      api.activeHikes = [_hike()];
      await open(tester);
      api.activeHikes = [_hike(), _hike(hID: 2, hiker: 'Sara Verdi')];

      await tester.fling(find.text('1 active hike'), const Offset(0, 1000), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 active hikes'), findsOneWidget);
    });

    testWidgets('the automatic refresh stops when the list is closed', (tester) async {
      await open(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final calls = api.called('listActiveHikes').length;

      await tester.pump(const Duration(seconds: 90));
      expect(api.called('listActiveHikes'), hasLength(calls));
    });
  });
}
