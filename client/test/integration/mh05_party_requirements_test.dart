// MH-05 Provide party requirements — integration tests (booking form + confirmation, fake API)
import 'package:client/features/booking/presentation/pages/booking_page.dart';
import 'package:client/features/booking/presentation/pages/booking_success_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeBookingRepository repository;

  setUp(() {
    repository = FakeBookingRepository()
      ..response = {
        'booking': {'bID': 12, 'reference': 'MH-12', 'tables': [], 'requirements': []},
        'notification': {'status': 'accepted'},
      };
  });

  Future<void> open(WidgetTester tester) =>
      pumpPage(tester, BookingPage(allocation: allocation, repository: repository, api: FakeApi()));

  Future<void> addRequirement(WidgetTester tester, String text, {bool allergy = false}) async {
    await tester.tap(find.text('Add Dietary / Allergy Requirement'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, text);
    if (allergy) await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('CONFIRM RESERVATION'));
    await tester.pumpAndSettle();
  }

  testWidgets('requirements are optional', (tester) async {
    await open(tester);
    await confirm(tester);
    expect(repository.requests.single['requirements'], isEmpty);
  });

  testWidgets('example from the story: three requirements for subsets of the party', (tester) async {
    await open(tester);
    await addRequirement(tester, '1 vegan, peanut allergy', allergy: true);
    await addRequirement(tester, '1 shellfish allergy', allergy: true);
    await addRequirement(tester, '  2 vegetarians  ');
    expect(find.text('REQUIREMENT 03'), findsOneWidget);
    await confirm(tester);

    expect(repository.requests.single['requirements'], [
      {'description': '1 vegan, peanut allergy', 'allergy': true},
      {'description': '1 shellfish allergy', 'allergy': true},
      {'description': '2 vegetarians', 'allergy': false},
    ]);
  });

  testWidgets('checking the allergy box flags the requirement for the kitchen', (tester) async {
    await open(tester);
    await addRequirement(tester, 'nut allergy');
    expect(find.text('FLAGGED FOR CHEF'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('FLAGGED FOR CHEF'), findsOneWidget);
  });

  testWidgets('a new requirement cannot be added while the current one is empty', (tester) async {
    await open(tester);
    await tester.tap(find.text('Add Dietary / Allergy Requirement'));
    await tester.pump();
    await tester.tap(find.text('Add Dietary / Allergy Requirement'));
    await tester.pump();

    expect(find.text('Complete the current requirement before adding another.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('an empty requirement blocks the booking until it is filled or removed', (tester) async {
    await open(tester);
    await tester.tap(find.text('Add Dietary / Allergy Requirement'));
    await tester.pump();
    await confirm(tester);

    expect(find.text('Complete or remove empty requirements.'), findsOneWidget);
    expect(repository.requests, isEmpty);
  });

  testWidgets('a requirement can be removed before booking', (tester) async {
    await open(tester);
    await addRequirement(tester, 'gluten free');
    await tester.tap(find.byTooltip('Remove requirement'));
    await tester.pump();
    await confirm(tester);

    expect(repository.requests.single['requirements'], isEmpty);
  });

  testWidgets('the confirmation lists the requirements and highlights allergies', (tester) async {
    await pumpPage(
      tester,
      BookingSuccessPage(
        api: FakeApi(),
        allocation: allocation,
        notificationSent: true,
        booking: {
          'bID': 12,
          'reference': 'MH-12',
          'tables': [],
          'requirements': [
            {'description': 'peanut allergy', 'allergy': true, 'n_people': 1},
            {'description': '2 vegetarians', 'allergy': false, 'n_people': null},
          ],
        },
      ),
    );

    expect(find.text('peanut allergy (Kitchen Alert), 2 vegetarians'), findsOneWidget);
    expect(find.text('KITCHEN ALERT'), findsOneWidget);
  });
}
