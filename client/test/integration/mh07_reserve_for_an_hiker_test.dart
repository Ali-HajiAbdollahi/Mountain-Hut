// MH-07 Reserve for an hiker — integration tests (staff: quick hiker lookup and
// "Add New Hiker" form with Temporary Hiker / Regular Profile). The backend is replaced by FakeApi.
// Note: the "Phone / Walk-in Booking" tab of the staff portal is still a placeholder, so the
// booking request made on behalf of the hiker (POST /api/staff/bookings) has no UI to test yet.
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/staff_portal/presentation/widgets/add_hiker_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _elena = {'uID': 4, 'name': 'Elena Rossi', 'email': 'elena@alpinists.ch', 'phone': '+41 78 890 1234'};
const _marco = {'uID': 9, 'name': 'Marco Rossi', 'email': 'marco@alpinists.ch', 'phone': null};

void main() {
  late FakeApi api;
  HikerChoice? confirmed;

  setUp(() {
    api = FakeApi();
    confirmed = null;
  });

  Future<void> open(WidgetTester tester) => pumpPage(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AddHikerForm(api: api, onConfirmed: (choice) => confirmed = choice),
          ),
        ),
      );

  Finder searchField() => find.byType(TextFormField).first;

  /// Types in the lookup field and waits for the 400 ms debounce.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(searchField(), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder fieldWithHint(String hint) => find.widgetWithText(TextFormField, hint);

  group('Quick hiker lookup', () {
    testWidgets('searches only after the employee stops typing (400 ms debounce)', (tester) async {
      await open(tester);

      await tester.enterText(searchField(), 'ros');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(searchField(), 'rossi');
      await tester.pump(const Duration(milliseconds: 399));
      expect(api.called('searchHikers'), isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(api.called('searchHikers').single.args['query'], 'rossi');
    });

    testWidgets('fewer than 2 characters do not call the server', (tester) async {
      await open(tester);
      await search(tester, 'r');
      expect(api.called('searchHikers'), isEmpty);
    });

    testWidgets('the query is sent trimmed', (tester) async {
      await open(tester);
      await search(tester, '  rossi  ');
      expect(api.called('searchHikers').single.args['query'], 'rossi');
    });

    testWidgets('shows the matching hikers with email and phone', (tester) async {
      api.hikers = [_elena, _marco];
      await open(tester);
      await search(tester, 'rossi');

      expect(find.text('Elena Rossi'), findsOneWidget);
      expect(find.text('elena@alpinists.ch · +41 78 890 1234'), findsOneWidget);
      expect(find.text('Marco Rossi'), findsOneWidget);
      expect(find.text('marco@alpinists.ch'), findsOneWidget);
    });

    testWidgets('selecting a hiker locks the field and "Confirm Hiker" returns the existing hiker',
        (tester) async {
      api.hikers = [_elena, _marco];
      await open(tester);
      await search(tester, 'rossi');

      await tap(tester, find.text('Elena Rossi'));
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
      expect(find.text('Marco Rossi'), findsNothing); // the dropdown is closed

      await tap(tester, find.text('Confirm Hiker'));
      expect(confirmed, isA<ExistingHiker>().having((c) => c.hiker.uId, 'uId', 4));
    });

    testWidgets('"Change" clears the selected hiker', (tester) async {
      api.hikers = [_elena];
      await open(tester);
      await search(tester, 'elena');
      await tap(tester, find.text('Elena Rossi'));

      await tap(tester, find.text('Change'));
      expect(find.text('Confirm Hiker'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    });

    testWidgets('a server error is shown and the "Add New Hiker" form is not opened', (tester) async {
      api.hikersError = const ApiException(403, 'FORBIDDEN', 'Employee account required');
      await open(tester);
      await search(tester, 'rossi');

      expect(find.text('Employee account required'), findsOneWidget);
      expect(find.text('GUEST PROFILE MODE'), findsNothing);
    });
  });

  group('Hiker not found: Add New Hiker', () {
    Future<void> notFound(WidgetTester tester) async {
      api.hikers = [];
      await open(tester);
      await search(tester, 'martin');
    }

    testWidgets('tells the employee and opens the form in "Temporary Hiker" mode', (tester) async {
      await notFound(tester);

      expect(find.textContaining('No registered hiker found'), findsOneWidget);
      expect(find.text('GUEST PROFILE MODE'), findsOneWidget);
      expect(find.text('Confirm Temporary Hiker'), findsOneWidget);
      expect(find.text('Confirm Registration'), findsNothing);
    });

    testWidgets('Temporary Hiker: the name is required', (tester) async {
      await notFound(tester);
      await tap(tester, find.text('Confirm Temporary Hiker'));

      expect(find.text('Name is required'), findsOneWidget);
      expect(confirmed, isNull);
    });

    testWidgets('Temporary Hiker: returns name and phone', (tester) async {
      await notFound(tester);
      await tester.enterText(fieldWithHint('e.g. Martin S. (Walk-in)'), '  Martin S.  ');
      await tester.enterText(fieldWithHint('+41 79 123 4567'), '+41 79 000 0000');
      await tap(tester, find.text('Confirm Temporary Hiker'));

      expect(confirmed, isA<TemporaryHiker>()
          .having((c) => c.name, 'name', 'Martin S.')
          .having((c) => c.phone, 'phone', '+41 79 000 0000'));
    });

    testWidgets('Temporary Hiker: the phone is optional', (tester) async {
      await notFound(tester);
      await tester.enterText(fieldWithHint('e.g. Martin S. (Walk-in)'), 'Martin S.');
      await tap(tester, find.text('Confirm Temporary Hiker'));

      expect(confirmed, isA<TemporaryHiker>().having((c) => c.phone, 'phone', isNull));
    });

    testWidgets('Regular Profile: every field is validated', (tester) async {
      await notFound(tester);
      await tap(tester, find.text('Regular Profile'));
      expect(find.text('PERSISTENT HIKER MEMBERSHIP FILE'), findsOneWidget);

      await tap(tester, find.text('Confirm Registration'));
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Mobile Phone is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      await tester.enterText(fieldWithHint('elena.rossi@alpinists.ch'), 'elena');
      await tester.enterText(fieldWithHint('••••••••'), 'short');
      await tap(tester, find.text('Confirm Registration'));
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(confirmed, isNull);
    });

    testWidgets('Regular Profile: returns name, email, phone and password', (tester) async {
      await notFound(tester);
      await tap(tester, find.text('Regular Profile'));

      await tester.enterText(fieldWithHint('Elena Rossi'), 'Anna Bianchi');
      await tester.enterText(fieldWithHint('elena.rossi@alpinists.ch'), 'anna@hut.it');
      await tester.enterText(fieldWithHint('+41 78 890 1234'), '+39 333 1234567');
      await tester.enterText(fieldWithHint('••••••••'), 'password123');
      await tap(tester, find.text('Confirm Registration'));

      expect(confirmed, isA<RegisterHiker>()
          .having((c) => c.name, 'name', 'Anna Bianchi')
          .having((c) => c.email, 'email', 'anna@hut.it')
          .having((c) => c.phone, 'phone', '+39 333 1234567')
          .having((c) => c.password, 'password', 'password123'));
    });

    testWidgets('a later search that finds the hiker closes the form', (tester) async {
      await notFound(tester);
      api.hikers = [_elena];
      await search(tester, 'elena');
      await tap(tester, find.text('Elena Rossi'));

      expect(find.text('GUEST PROFILE MODE'), findsNothing);
      expect(find.text('Confirm Hiker'), findsOneWidget);
    });
  });
}
