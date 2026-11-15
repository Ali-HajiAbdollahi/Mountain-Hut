// MH-11 View meal details — integration tests (MealServiceSlotCard + ExplorePage, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/booking/presentation/widgets/meal_service_slot_card.dart';
import 'package:client/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _menuKey = ValueKey('slot-menu-content');
const _noMenu = 'No menu has been published for this slot.';
const _menuHeader = 'SLOT MENU • INCLUDED OPTIONS';

/// The menu text currently displayed (without formatting).
String _shownMenu(WidgetTester tester) =>
    tester.widget<RichText>(find.byKey(_menuKey)).text.toPlainText();

/// The text pieces of the displayed menu with their style.
Map<String, TextStyle> _menuStyles(WidgetTester tester) {
  final span = tester.widget<RichText>(find.byKey(_menuKey)).text as TextSpan;
  return {for (final c in span.children!.cast<TextSpan>()) c.text!: c.style!};
}

void main() {
  group('MealServiceSlotCard', () {
    Future<void> showCard(WidgetTester tester, {required bool selected, String? menu}) =>
        pumpPage(
          tester,
          Scaffold(
            body: MealServiceSlotCard(
              label: 'Lunch 12:00 - 13:00',
              leadingIcon: Icons.lunch_dining,
              selected: selected,
              menuHtml: menu,
              onTap: () {},
            ),
          ),
        );

    testWidgets('a selected slot shows the meal time and its menu', (tester) async {
      await showCard(tester, selected: true, menu: 'Polenta<br>Apple tart');

      expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
      expect(find.text(_menuHeader), findsOneWidget);
      expect(_shownMenu(tester), 'Polenta\nApple tart');
    });

    testWidgets('a slot that is not selected shows only the meal time', (tester) async {
      await showCard(tester, selected: false, menu: 'Polenta');

      expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
      expect(find.text(_menuHeader), findsNothing);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('says so when no menu has been published', (tester) async {
      await showCard(tester, selected: true, menu: null);
      expect(find.text(_noMenu), findsOneWidget);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('a blank menu is treated as no menu', (tester) async {
      await showCard(tester, selected: true, menu: '   ');
      expect(find.text(_noMenu), findsOneWidget);
    });

    testWidgets('shows the formatting chosen by the staff: bold, italic and bullet list', (tester) async {
      await showCard(
        tester,
        selected: true,
        menu: '<strong>Starters</strong><br>• Soup<br>  • <em>with croutons</em>',
      );

      expect(_shownMenu(tester), 'Starters\n• Soup\n  • with croutons');
      final styles = _menuStyles(tester);
      expect(styles['Starters']!.fontWeight, FontWeight.bold);
      expect(styles['with croutons']!.fontStyle, FontStyle.italic);
    });

    testWidgets('shows no HTML tags or entities to the reader', (tester) async {
      await showCard(tester, selected: true, menu: '<strong>Fish &amp; chips</strong>');
      expect(_shownMenu(tester), 'Fish & chips');
    });
  });

  group('ExplorePage (public meal details)', () {
    late FakeApi api;

    setUp(() {
      api = FakeApi() // nobody is logged in (currentUser -> 401)
        ..slots = [
          {
            ...slotJson(tsID: 3, start: '2026-12-01 12:00', end: '2026-12-01 13:00'),
            'menu': '<strong>Polenta</strong> with mushrooms',
          },
          {
            ...slotJson(tsID: 4, start: '2026-12-01 19:00', end: '2026-12-01 20:30'),
            'menu': 'Venison stew',
          },
          {
            ...slotJson(tsID: 5, start: '2026-12-01 21:00', end: '2026-12-01 22:00'),
            'menu': null,
          },
        ];
    });

    Future<void> open(WidgetTester tester) =>
        pumpPage(tester, ExplorePage(authRepository: FakeAuthRepository(), api: api));

    testWidgets('a visitor without login sees the meal times of the day', (tester) async {
      await open(tester);

      expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
      expect(find.text('Dinner 19:00 - 20:30'), findsOneWidget);
      expect(find.text('Meal 21:00 - 22:00'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('the menu of the first slot is shown when the page opens', (tester) async {
      await open(tester);

      expect(find.byKey(_menuKey), findsOneWidget);
      expect(_shownMenu(tester), 'Polenta with mushrooms');
      expect(_menuStyles(tester)['Polenta']!.fontWeight, FontWeight.bold);
    });

    testWidgets('choosing another slot shows its own menu', (tester) async {
      await open(tester);
      await tester.tap(find.text('Dinner 19:00 - 20:30'));
      await tester.pumpAndSettle();

      expect(find.byKey(_menuKey), findsOneWidget);
      expect(_shownMenu(tester), 'Venison stew');
    });

    testWidgets('a slot without a published menu says so', (tester) async {
      await open(tester);
      await tester.tap(find.text('Meal 21:00 - 22:00'));
      await tester.pumpAndSettle();

      expect(find.text(_noMenu), findsOneWidget);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('a day without meals shows no menu', (tester) async {
      api.slots = [];
      await open(tester);

      expect(find.text('No meal service slots are available for this date.'), findsOneWidget);
      expect(find.text(_menuHeader), findsNothing);
    });

    testWidgets('when meals cannot be loaded the error is shown instead of the menus', (tester) async {
      api.slotsError = const ApiException(503, 'DATABASE_BUSY', 'Please retry shortly');
      await open(tester);

      expect(find.text('Please retry shortly'), findsOneWidget);
      expect(find.text(_menuHeader), findsNothing);
    });
  });
}
