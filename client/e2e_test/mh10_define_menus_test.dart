// MH-10 Define menus — E2E (real app + real backend)
// As an employee I can specify the menus of the defined slots, so that hikers know when the
// hut is providing the service. Clarification: free text, with the option to reuse (and
// change) previous menus, and basic formatting (bold, italic, item list and sub-items).
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/rich_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e.dart';

const _editorKey = ValueKey('slot-menu-editor');
const _publish = 'SAVE & PUBLISH MENU';

DateTime _previous(DateTime day) => DateTime(day.year, day.month, day.day - 1);

/// A fresh day whose previous day has no slots either.
Future<DateTime> _freshDayAfterFreeDay() async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final day = await freshDay();
    if ((await slotsOn(_previous(day))).isEmpty) return day;
  }
  throw StateError('No free pair of days found');
}

Future<String?> _menuOf(int slotId) async => (await MountainHutApi().getSlot(slotId))['menu'] as String?;

Future<void> _publishMenu(int slotId, String html) =>
    asUser(staffEmail, (api) => api.publishSlotMenu(slotId, html));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DateTime day;
  late int lunchId;
  late int dinnerId;

  setUpAll(checkBackend);

  setUp(() async {
    day = await _freshDayAfterFreeDay();
    lunchId = await createSlot(day, '12:00', '13:00', tablesOf([4]));
    dinnerId = await createSlot(day, '19:00', '20:00', tablesOf([4]));
  });

  Future<void> openStaffPortalOn(WidgetTester tester, DateTime target) async {
    await launchApp(tester);
    await signInFromNavigation(tester, staffEmail);
    await tap(tester, find.text('Dining'));
    await waitFor(tester, find.text('SERVICE SLOTS'));
    await tap(tester, find.text('Change'));
    await typeInDatePicker(tester, target);
    await waitUntilGone(tester, find.byType(CircularProgressIndicator));
    await tap(tester, find.byKey(const ValueKey('slot-tab-menu')));
    await waitFor(tester, find.text('SLOT MENU CONFIGURATION'));
  }

  RichTextController editor(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(_editorKey)).controller! as RichTextController;

  Future<void> select(WidgetTester tester, int start, int end) async {
    editor(tester).selection = TextSelection(baseOffset: start, extentOffset: end);
    await tester.pump();
  }

  Future<void> caretAt(WidgetTester tester, int offset) async {
    editor(tester).selection = TextSelection.collapsed(offset: offset);
    await tester.pump();
  }

  Future<void> replaceText(WidgetTester tester, String old, String text) async {
    final current = editor(tester).text;
    final start = current.indexOf(old);
    editor(tester).value = TextEditingValue(
      text: current.replaceRange(start, start + old.length, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    await tester.pump();
  }

  Future<void> publish(WidgetTester tester) async {
    await waitUntilGone(tester, find.text('Menu published successfully.'));
    await tap(tester, find.text(_publish));
    await waitFor(tester, find.text('Menu published successfully.'));
  }

  testWidgets('the employee writes a formatted menu and visitors see it with its formatting', (tester) async {
    await openStaffPortalOn(tester, day);
    expect(find.text('12:00–13:00'), findsOneWidget);

    await type(tester, find.byKey(_editorKey), 'Polenta with mushrooms\nDesserts\nStrudel');
    await select(tester, 0, 7);
    await tap(tester, find.byTooltip('Bold'));
    await select(tester, 13, 22);
    await tap(tester, find.byTooltip('Italic'));
    await caretAt(tester, 23);
    await tap(tester, find.byTooltip('Bulleted list'));
    await caretAt(tester, 35);
    await tap(tester, find.byTooltip('Bulleted list'));
    await tap(tester, find.byTooltip('Indent'));
    await publish(tester);

    expect(await _menuOf(lunchId),
        '<strong>Polenta</strong> with <em>mushrooms</em><br>• Desserts<br>  • Strudel');

    await launchApp(tester);
    await chooseSearchDate(tester, day);
    await waitFor(tester, find.text('Lunch 12:00 - 13:00'));
    final shown = tester.widget<RichText>(find.byKey(const ValueKey('slot-menu-content')));
    expect(shown.text.toPlainText(), 'Polenta with mushrooms\n• Desserts\n  • Strudel');
  });

  testWidgets('each slot gets its own menu', (tester) async {
    await openStaffPortalOn(tester, day);
    await type(tester, find.byKey(_editorKey), 'Barley soup');
    await publish(tester);

    await tap(tester, find.text('19:00 – 20:00'));
    await waitFor(tester, find.text('19:00–20:00'));
    expect(editor(tester).text, isEmpty);
    await tap(tester, find.byKey(_editorKey));
    await type(tester, find.byKey(_editorKey), 'Venison stew');
    expect(editor(tester).text, 'Venison stew');
    await publish(tester);

    expect(await _menuOf(lunchId), 'Barley soup');
    expect(await _menuOf(dinnerId), 'Venison stew');
  });

  testWidgets('an existing menu is shown in the editor and can be changed', (tester) async {
    await _publishMenu(lunchId, '<strong>Polenta</strong><br>• Apple tart');

    await openStaffPortalOn(tester, day);
    await waitFor(tester, find.byKey(_editorKey));
    expect(editor(tester).text, 'Polenta\n• Apple tart');

    await replaceText(tester, 'Polenta', 'Risotto');
    await publish(tester);
    expect(await _menuOf(lunchId), '<strong>Risotto</strong><br>• Apple tart');
  });

  testWidgets('a menu of a previous day is reused, changed and published without changing the original',
      (tester) async {
    final yesterday = await createSlot(_previous(day), '19:00', '20:00', tablesOf([4]));
    const original = '<strong>Canederli</strong><br>• Apple tart';
    await _publishMenu(yesterday, original);

    await openStaffPortalOn(tester, day);
    await tap(tester, find.byKey(const ValueKey('reuse-menu-select')));
    await tap(tester, find.text('${ymd(_previous(day))} 19:00 · Canederli  • Apple tart').last);
    await tap(tester, find.text('Apply'));
    expect(editor(tester).text, 'Canederli\n• Apple tart');

    await replaceText(tester, 'Apple tart', 'Strudel');
    await publish(tester);

    expect(await _menuOf(lunchId), '<strong>Canederli</strong><br>• Strudel');
    expect(await _menuOf(yesterday), original);
  });

  testWidgets('an empty menu cannot be published', (tester) async {
    await openStaffPortalOn(tester, day);
    await type(tester, find.byKey(_editorKey), '   ');

    final button = tester.widget<ButtonStyleButton>(
        find.ancestor(of: find.text(_publish), matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
    expect(await _menuOf(lunchId), isNull);
  });
}
