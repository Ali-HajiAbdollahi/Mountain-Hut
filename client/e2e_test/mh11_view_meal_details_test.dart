// MH-11 View meal details — E2E (real app + real backend)
// As a visitor I can see meal times and menus, so that I can plan my stay.
// The menus are published by the staff (MH-10); visitors see them without logging in.
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

const _menuKey = ValueKey('slot-menu-content');
const _noMenu = 'No menu has been published for this slot.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late int lunchId;

  setUpAll(checkBackend);

  setUp(() async {
    day = await freshDay();
    lunchId = await createSlot(day, '12:00', '13:00', tablesOf([4, 2]));
    final dinnerId = await createSlot(day, '19:00', '20:30', tablesOf([8]));
    await createSlot(day, '21:00', '22:00', tablesOf([4])); // no menu
    await publishMenu(lunchId, '<strong>Polenta</strong> with mushrooms<br>• Apple tart');
    await publishMenu(dinnerId, 'Venison stew<br>• <em>Blueberry</em> pie');
  });

  /// The menu text shown in the selected slot (without formatting).
  String shownMenu(WidgetTester tester) =>
      tester.widget<RichText>(find.byKey(_menuKey)).text.toPlainText();

  /// The style of the menu piece [text] (e.g. a bold word).
  TextStyle styleOf(WidgetTester tester, String text) {
    final span = tester.widget<RichText>(find.byKey(_menuKey)).text as TextSpan;
    return span.children!.cast<TextSpan>().firstWhere((c) => c.text == text).style!;
  }

  Future<void> openExploreOn(WidgetTester tester, DateTime target) async {
    await launchApp(tester); // nobody is logged in
    await chooseSearchDate(tester, target);
    await waitFor(tester, find.text('Lunch 12:00 - 13:00'));
  }

  testWidgets('a visitor without login sees the meal times and the lunch menu of the chosen day',
      (tester) async {
    await openExploreOn(tester, day);

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Lunch 12:00 - 13:00'), findsOneWidget);
    expect(find.text('Dinner 19:00 - 20:30'), findsOneWidget);
    expect(find.text('Meal 21:00 - 22:00'), findsOneWidget);

    expect(find.text('SLOT MENU • INCLUDED OPTIONS'), findsOneWidget);
    expect(shownMenu(tester), 'Polenta with mushrooms\n• Apple tart');
    expect(styleOf(tester, 'Polenta').fontWeight, FontWeight.bold);
  });

  testWidgets('choosing dinner shows the dinner menu, which differs from lunch', (tester) async {
    await openExploreOn(tester, day);
    await tap(tester, find.text('Dinner 19:00 - 20:30'));

    expect(shownMenu(tester), 'Venison stew\n• Blueberry pie');
    expect(styleOf(tester, 'Blueberry').fontStyle, FontStyle.italic);
  });

  testWidgets('a slot without a published menu says so', (tester) async {
    await openExploreOn(tester, day);
    await tap(tester, find.text('Meal 21:00 - 22:00'));

    expect(find.text(_noMenu), findsOneWidget);
    expect(find.byKey(_menuKey), findsNothing);
  });

  testWidgets('when the staff change a menu, visitors see the new one', (tester) async {
    await publishMenu(lunchId, 'Barley soup');
    await openExploreOn(tester, day);

    expect(shownMenu(tester), 'Barley soup');
  });

  testWidgets('a menu published in the staff portal is shown to visitors', (tester) async {
    final other = await freshDay();
    final slotId = await createSlot(other, '12:00', '13:00', tablesOf([4]));

    // the employee writes and publishes the menu (the only slot of the day is selected)
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Staff Portal'));
    await waitFor(tester, find.text('SERVICE SLOTS'));
    await tap(tester, find.text('Change'));
    await typeInDatePicker(tester, other);
    await waitUntilGone(tester, find.byType(CircularProgressIndicator));
    await type(tester, find.byKey(const ValueKey('slot-menu-editor')), 'Canederli\nStrudel');
    await tap(tester, find.text('SAVE & PUBLISH MENU'));
    await waitFor(tester, find.text('Menu published successfully.'));

    expect((await MountainHutApi().getSlot(slotId))['menu'], 'Canederli<br>Strudel');

    // a visitor (new app, no session) sees it
    await openExploreOn(tester, other);
    expect(shownMenu(tester), 'Canederli\nStrudel');
  });
}

/// Publishes [html] as the menu of [slotId], as the seeded employee.
Future<void> publishMenu(int slotId, String html) =>
    asUser(staffEmail, (api) => api.publishSlotMenu(slotId, html));
