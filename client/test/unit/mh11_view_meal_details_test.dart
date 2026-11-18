// MH-11 View meal details — unit tests (API client, menu model, menu formatting)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/rich_text_controller.dart';
import 'package:client/features/staff_portal/domain/entities/service_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

const _lunch = {
  'tsID': 5,
  'start_time': '2026-12-01 12:00',
  'end_time': '2026-12-01 13:00',
  'capacity': 6,
  'free_seats': 6,
  'tables': [{'table_no': 1, 'seats': 6, 'free_seats': 6}],
  'menu': '<strong>Polenta</strong><br>Apple tart',
};

void main() {
  group('MountainHutApi.listSlots', () {
    test('asks for the meals of a day with GET /api/timeslots?date=', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([_lunch]));
      await api.listSlots('2026-12-01');

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/timeslots');
      expect(requests.single.query, {'date': '2026-12-01'});
    });

    test('is public: no cookie is sent when nobody has logged in', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([]));
      await api.listSlots('2026-12-01');
      expect(requests.single.request.headers.containsKey('Cookie'), isFalse);
    });

    test('returns meal times and the menu of each slot, null when not published', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([
            _lunch,
            {..._lunch, 'tsID': 6, 'start_time': '2026-12-01 19:00', 'end_time': '2026-12-01 20:30', 'menu': null},
          ]));
      final slots = await api.listSlots('2026-12-01');

      expect(slots.map((s) => [s['start_time'], s['end_time']]), [
        ['2026-12-01 12:00', '2026-12-01 13:00'],
        ['2026-12-01 19:00', '2026-12-01 20:30'],
      ]);
      expect(slots[0]['menu'], '<strong>Polenta</strong><br>Apple tart');
      expect(slots[1]['menu'], isNull);
    });

    test('a day without meals gives an empty list', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([]));
      expect(await api.listSlots('2026-12-25'), isEmpty);
    });
  });

  group('MountainHutApi.getSlot', () {
    test('asks for one meal with GET /api/timeslots/:id and returns its menu', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(_lunch));
      final slot = await api.getSlot(5);

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/timeslots/5');
      expect(slot['menu'], '<strong>Polenta</strong><br>Apple tart');
    });

    test('an unknown slot (404) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(404, 'NOT_FOUND', 'Slot not found'));
      await expectLater(
        api.getSlot(99),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.message, 'message', 'Slot not found')),
      );
    });
  });

  group('ServiceSlot.fromJson', () {
    test('reads the menu of the slot', () {
      expect(ServiceSlot.fromJson(_lunch).menu, '<strong>Polenta</strong><br>Apple tart');
    });

    test('a slot without menu has menu null', () {
      expect(ServiceSlot.fromJson({..._lunch, 'menu': null}).menu, isNull);
      expect(ServiceSlot.fromJson(Map.of(_lunch)..remove('menu')).menu, isNull);
    });
  });

  group('RichTextController.loadHtml (how the menu is displayed)', () {
    test('shows the text without the HTML tags, with <br> as a new line', () {
      final menu = RichTextController(html: '<strong>Polenta</strong><br>Apple tart');
      expect(menu.text, 'Polenta\nApple tart');
    });

    test('decodes the HTML entities', () {
      final menu = RichTextController(html: 'Fish &amp; chips &lt;3 &quot;home&quot; &#39;made&#39;');
      expect(menu.text, 'Fish & chips <3 "home" \'made\'');
    });

    test('keeps bullet points and indented sub-items as typed in the editor', () {
      final menu = RichTextController(html: '• Starters<br>  • Soup<br>• Dessert');
      expect(menu.text.split('\n'), ['• Starters', '  • Soup', '• Dessert']);
    });

    testWidgets('renders bold, italic and font size as text styles', (tester) async {
      final menu = RichTextController(
        html: '<strong>Polenta</strong> with <em>mushrooms</em><span style="font-size: 20px">Dessert</span>',
      );
      late TextSpan span;
      await tester.pumpWidget(Builder(builder: (context) {
        span = menu.buildTextSpan(context: context, withComposing: false);
        return const SizedBox();
      }));

      final parts = {for (final c in span.children!.cast<TextSpan>()) c.text!: c.style!};
      expect(parts['Polenta']!.fontWeight, FontWeight.bold);
      expect(parts[' with ']!.fontWeight, isNull);
      expect(parts['mushrooms']!.fontStyle, FontStyle.italic);
      expect(parts['Dessert']!.fontSize, 20);
    });

    test('an empty menu gives an empty text', () {
      expect(RichTextController(html: '').text, isEmpty);
    });
  });
}
