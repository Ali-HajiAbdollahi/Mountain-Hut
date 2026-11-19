// MH-10 Define menus — unit tests (API client, rich text editor controller)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/rich_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

/// Types [text] at the end of the editor, as the keyboard does.
void _type(RichTextController menu, String text) {
  final value = menu.text + text;
  menu.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
}

void _select(RichTextController menu, int start, int end) {
  menu.selection = TextSelection(baseOffset: start, extentOffset: end);
}

void main() {
  group('MountainHutApi.publishSlotMenu', () {
    test('sends the menu with PUT /api/timeslots/:id/menu', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'tsID': 3, 'menu': '<strong>Soup</strong>'}));
      final saved = await api.publishSlotMenu(3, '<strong>Soup</strong>');

      expect(requests.single.method, 'PUT');
      expect(requests.single.path, '/api/timeslots/3/menu');
      expect(requests.single.json, {'menu': '<strong>Soup</strong>'});
      expect(saved, {'tsID': 3, 'menu': '<strong>Soup</strong>'});
    });

    test('an invalid menu (400) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'menu must be a non-empty string'));
      await expectLater(
        api.publishSlotMenu(3, ' '),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'menu must be a non-empty string')),
      );
    });

    test('an unknown slot (404) becomes an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(404, 'NOT_FOUND', 'Slot not found'));
      await expectLater(api.publishSlotMenu(99, 'Soup'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    });
  });

  group('MountainHutApi.recentMenus', () {
    test('asks for the menus before a time with GET /api/timeslots/menus/recent', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([]));
      await api.recentMenus('2026-12-05 12:00');

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/timeslots/menus/recent');
      expect(requests.single.query, {'before': '2026-12-05 12:00'});
    });

    test('returns the previous menus with the slot they come from', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([
            {'tsID': 2, 'start_time': '2026-12-04 19:00', 'end_time': '2026-12-04 20:00', 'menu': 'Venison stew'},
          ]));
      final menus = await api.recentMenus('2026-12-05 12:00');
      expect(menus.single, containsPair('menu', 'Venison stew'));
      expect(menus.single, containsPair('start_time', '2026-12-04 19:00'));
    });

    test('a hiker (403) gets an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(403, 'FORBIDDEN', 'Operation not allowed'));
      await expectLater(api.recentMenus('2026-12-05 12:00'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    });
  });

  group('RichTextController (writing a menu)', () {
    test('plain text is saved as is, new lines become <br>', () {
      final menu = RichTextController();
      _type(menu, 'Polenta\nApple tart');
      expect(menu.toHtml(), 'Polenta<br>Apple tart');
    });

    test('special characters are escaped, so they are not read as HTML', () {
      final menu = RichTextController();
      _type(menu, 'Fish & chips <3 > 2');
      expect(menu.toHtml(), 'Fish &amp; chips &lt;3 &gt; 2');
    });

    test('bold and italic apply to the selected text only', () {
      final menu = RichTextController();
      _type(menu, 'Polenta with mushrooms');
      _select(menu, 0, 7);
      menu.toggle(RichTextStyle.bold);
      _select(menu, 13, 22);
      menu.toggle(RichTextStyle.italic);

      expect(menu.toHtml(), '<strong>Polenta</strong> with <em>mushrooms</em>');
    });

    test('bold and italic can be combined', () {
      final menu = RichTextController();
      _type(menu, 'Strudel');
      _select(menu, 0, 7);
      menu.toggle(RichTextStyle.bold);
      menu.toggle(RichTextStyle.italic);
      expect(menu.toHtml(), '<strong><em>Strudel</em></strong>');
    });

    test('pressing bold again on the same text removes it', () {
      final menu = RichTextController();
      _type(menu, 'Soup');
      _select(menu, 0, 4);
      menu.toggle(RichTextStyle.bold);
      expect(menu.isActive(RichTextStyle.bold), isTrue);
      menu.toggle(RichTextStyle.bold);
      expect(menu.isActive(RichTextStyle.bold), isFalse);
      expect(menu.toHtml(), 'Soup');
    });

    test('a style chosen before typing applies to the next text', () {
      final menu = RichTextController();
      _type(menu, 'Lunch: ');
      menu.toggle(RichTextStyle.bold);
      _type(menu, 'Soup');
      expect(menu.toHtml(), 'Lunch: <strong>Soup</strong>');
    });

    test('the font size is saved as a span and can be reset', () {
      final menu = RichTextController();
      _type(menu, 'Dessert');
      _select(menu, 0, 7);
      menu.setFontSize(20);
      expect(menu.toHtml(), '<span style="font-size: 20px">Dessert</span>');

      menu.setFontSize(null);
      expect(menu.toHtml(), 'Dessert');
      expect(() => menu.setFontSize(120), throwsRangeError);
    });

    test('bullet points and indented sub-items are kept as typed', () {
      final menu = RichTextController();
      _type(menu, '• Starters\n  • Soup\n• Dessert');
      expect(menu.toHtml(), '• Starters<br>  • Soup<br>• Dessert');
    });

    test('a saved menu loads back with the same text and formatting', () {
      final menu = RichTextController();
      _type(menu, 'Polenta\n• Apple tart');
      _select(menu, 0, 7);
      menu.toggle(RichTextStyle.bold);
      final html = menu.toHtml();

      final reloaded = RichTextController(html: html);
      expect(reloaded.text, 'Polenta\n• Apple tart');
      expect(reloaded.toHtml(), html);
    });
  });
}
