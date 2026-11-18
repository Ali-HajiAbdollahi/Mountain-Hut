// MH-10 Define menus — integration tests (SlotMenuConfigurationCard, fake API)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/rich_text_controller.dart';
import 'package:client/features/staff_portal/domain/entities/service_slot.dart';
import 'package:client/features/staff_portal/presentation/widgets/slot_menu_configuration_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _editorKey = ValueKey('slot-menu-editor');
const _publish = 'SAVE & PUBLISH MENU';

ServiceSlot _lunch({String? menu}) => ServiceSlot.fromJson({
      ...slotJson(tsID: 5, start: '2026-12-05 12:00', end: '2026-12-05 13:00'),
      'menu': menu,
    });

void main() {
  late FakeApi api;
  late List<(int, String)> published;

  setUp(() {
    api = FakeApi();
    published = [];
  });

  Future<void> open(WidgetTester tester, {ServiceSlot? slot}) => pumpPage(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: SlotMenuConfigurationCard(
              api: api,
              slot: slot,
              onMenuPublished: (id, menu) => published.add((id, menu)),
            ),
          ),
        ),
      );

  RichTextController editor(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(_editorKey)).controller! as RichTextController;

  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(_editorKey), text);
    await tester.pump();
  }

  void select(WidgetTester tester, int start, int end) =>
      editor(tester).selection = TextSelection(baseOffset: start, extentOffset: end);

  void caretAt(WidgetTester tester, int offset) =>
      editor(tester).selection = TextSelection.collapsed(offset: offset);

  Future<void> press(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()))
      .onPressed != null;

  Future<String> publish(WidgetTester tester) async {
    await tester.tap(find.text(_publish));
    await tester.pumpAndSettle();
    return api.called('publishSlotMenu').last.args['menu'] as String;
  }

  group('Editing the menu of a slot', () {
    testWidgets('without a slot nothing can be written or published', (tester) async {
      await open(tester);

      expect(find.text('NO SLOT'), findsOneWidget);
      expect(find.text('Select or create a service slot before adding its menu.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_editorKey)).enabled, isFalse);
      expect(enabled(tester, _publish), isFalse);
      expect(api.called('recentMenus'), isEmpty);
    });

    testWidgets('shows the selected slot and its current menu, without HTML tags', (tester) async {
      await open(tester, slot: _lunch(menu: '<strong>Polenta</strong><br>Apple tart'));

      expect(find.text('12:00–13:00'), findsOneWidget);
      expect(editor(tester).text, 'Polenta\nApple tart');
      expect(editor(tester).toHtml(), '<strong>Polenta</strong><br>Apple tart');
    });

    testWidgets('an empty menu, or one of only spaces, cannot be published', (tester) async {
      await open(tester, slot: _lunch());
      expect(enabled(tester, _publish), isFalse);

      await write(tester, '   ');
      expect(enabled(tester, _publish), isFalse);

      await write(tester, 'Barley soup');
      expect(enabled(tester, _publish), isTrue);
    });

    testWidgets('free text is published for the slot, with new lines kept', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Polenta\nApple tart');

      expect(await publish(tester), 'Polenta<br>Apple tart');
      expect(api.called('publishSlotMenu').single.args['slotId'], 5);
      expect(find.text('Menu published successfully.'), findsOneWidget);
      expect(published, [(5, 'Polenta<br>Apple tart')]);
    });

    testWidgets('the "B" and "I" buttons make the selected text bold or italic', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Polenta with mushrooms');
      select(tester, 0, 7);
      await press(tester, 'Bold');
      select(tester, 13, 22);
      await press(tester, 'Italic');

      expect(await publish(tester), '<strong>Polenta</strong> with <em>mushrooms</em>');
    });

    testWidgets('the font size menu changes the size of the selected text', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Dessert');
      select(tester, 0, 7);
      await press(tester, 'Font size');
      await tester.tap(find.text('20').last);
      await tester.pumpAndSettle();

      expect(await publish(tester), '<span style="font-size: 20px">Dessert</span>');
    });

    testWidgets('the list button adds a bullet to the line, and removes it when pressed again', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Soup');
      caretAt(tester, 4);
      await press(tester, 'Bulleted list');
      expect(editor(tester).text, '• Soup');

      await press(tester, 'Bulleted list');
      expect(editor(tester).text, 'Soup');
    });

    testWidgets('a bullet followed by indent makes a sub-item', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Starters\nSoup');
      caretAt(tester, 13);
      await press(tester, 'Bulleted list');
      await press(tester, 'Indent');

      expect(editor(tester).text, 'Starters\n  • Soup');
      expect(await publish(tester), 'Starters<br>  • Soup');
    });

    testWidgets('the list button on a selection of several lines adds a bullet to each', (tester) async {
      await open(tester, slot: _lunch());
      await write(tester, 'Soup\nPolenta\nStrudel');
      select(tester, 0, 20);
      await press(tester, 'Bulleted list');

      expect(editor(tester).text, '• Soup\n• Polenta\n• Strudel');
    });

    testWidgets('a refused menu shows the server message and is not reported as published', (tester) async {
      api.publishMenuError = const ApiException(404, 'NOT_FOUND', 'Slot not found');
      await open(tester, slot: _lunch());
      await write(tester, 'Soup');
      await publish(tester);

      expect(find.text('Slot not found'), findsOneWidget);
      expect(find.text('Menu published successfully.'), findsNothing);
      expect(published, isEmpty);
    });
  });

  group('Reusing a previous menu', () {
    setUp(() {
      api.recentMenuRows = [
        {
          'tsID': 2,
          'start_time': '2026-12-04 19:00',
          'end_time': '2026-12-04 20:00',
          'menu': '<strong>Venison stew</strong><br>• Blueberry pie',
        },
        {'tsID': 1, 'start_time': '2026-11-28 12:00', 'end_time': '2026-11-28 13:00', 'menu': 'Canederli'},
      ];
    });

    Future<void> choose(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const ValueKey('reuse-menu-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the menus used before the start of the slot', (tester) async {
      await open(tester, slot: _lunch());
      expect(api.called('recentMenus').single.args['before'], '2026-12-05 12:00');
      expect(find.text('Choose a previous menu'), findsOneWidget);
    });

    testWidgets('lists the menus of previous days with date, time and text without tags', (tester) async {
      await open(tester, slot: _lunch());
      await tester.tap(find.byKey(const ValueKey('reuse-menu-select')));
      await tester.pumpAndSettle();

      expect(find.text('2026-12-04 19:00 · Venison stew  • Blueberry pie'), findsWidgets);
      expect(find.text('2026-11-28 12:00 · Canederli'), findsWidgets);
    });

    testWidgets('"Apply" loads the chosen menu, with its formatting, into the editor', (tester) async {
      await open(tester, slot: _lunch());
      expect(enabled(tester, 'Apply'), isFalse);

      await choose(tester, '2026-12-04 19:00 · Venison stew  • Blueberry pie');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(editor(tester).text, 'Venison stew\n• Blueberry pie');
      expect(editor(tester).toHtml(), '<strong>Venison stew</strong><br>• Blueberry pie');
      expect(api.called('publishSlotMenu'), isEmpty);
    });

    testWidgets('a reused menu can be changed before it is published', (tester) async {
      await open(tester, slot: _lunch());
      await choose(tester, '2026-11-28 12:00 · Canederli');
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await write(tester, 'Canederli\n• Strudel');

      expect(await publish(tester), 'Canederli<br>• Strudel');
    });

    testWidgets('without previous menus the picker says so and nothing can be applied', (tester) async {
      api.recentMenuRows = [];
      await open(tester, slot: _lunch());

      expect(find.text('No earlier menus available'), findsOneWidget);
      expect(enabled(tester, 'Apply'), isFalse);
    });

    testWidgets('when the menus cannot be loaded, they can be loaded again', (tester) async {
      api.recentMenusError = const ApiException(503, 'DATABASE_BUSY', 'Please retry shortly');
      await open(tester, slot: _lunch());
      expect(find.text('Could not load previous menus'), findsOneWidget);

      api.recentMenusError = null;
      await press(tester, 'Retry menu history');
      expect(find.text('Choose a previous menu'), findsOneWidget);
      expect(api.called('recentMenus'), hasLength(2));
    });
  });
}
