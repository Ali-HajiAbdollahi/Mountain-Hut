// MH-02 Define slot capacity — unit tests (API client, slot/table entities, date formatting)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/staff_portal/domain/entities/service_slot.dart';
import 'package:client/features/staff_portal/domain/entities/table_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  final slot = {'tsID': 3, 'capacity': 8, 'free_seats': 8, 'tables': []};

  group('MountainHutApi.createSlot', () {
    test('sends start, end and the table layout', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(slot, 201));
      await api.createSlot(
        startTime: '2026-12-01 12:00',
        endTime: '2026-12-01 13:00',
        tables: [{'table_no': 1, 'seats': 2}, {'table_no': 2, 'seats': 6}],
      );

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/timeslots');
      expect(requests.single.json, {
        'start_time': '2026-12-01 12:00',
        'end_time': '2026-12-01 13:00',
        'tables': [{'table_no': 1, 'seats': 2}, {'table_no': 2, 'seats': 6}],
      });
    });

    test('can reuse the layout of a previous slot instead of re-entering it', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(slot, 201));
      await api.createSlot(startTime: '2026-12-01 13:00', endTime: '2026-12-01 14:00', copyFromTsId: 3);

      expect(requests.single.json,
          {'start_time': '2026-12-01 13:00', 'end_time': '2026-12-01 14:00', 'copy_from_tsID': 3});
    });

    test('requires exactly one of tables and copyFromTsId, without calling the server', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(slot, 201));
      expect(() => api.createSlot(startTime: 'a', endTime: 'b'), throwsArgumentError);
      expect(
        () => api.createSlot(startTime: 'a', endTime: 'b', tables: [], copyFromTsId: 3),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });

    test('a non-employee gets the 403 from the server as an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(403, 'FORBIDDEN', 'Operation not allowed'));
      await expectLater(
        api.createSlot(startTime: 'a', endTime: 'b', tables: []),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });
  });

  group('MountainHutApi.defineTables', () {
    test('sends PUT /api/timeslots/:id/tables', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(slot));
      await api.defineTables(3, tables: [{'table_no': 1, 'seats': 4}]);

      expect(requests.single.method, 'PUT');
      expect(requests.single.path, '/api/timeslots/3/tables');
      expect(requests.single.json, {'tables': [{'table_no': 1, 'seats': 4}]});
    });

    test('requires exactly one of tables and copyFromTsId', () {
      final (:api, requests: _) = apiWith((_) => jsonResponse(slot));
      expect(() => api.defineTables(3), throwsArgumentError);
    });
  });

  group('MountainHutApi.listSlots / getSlot', () {
    test('lists the slots of a date with their capacity', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([slot]));
      final slots = await api.listSlots('2026-12-01');

      expect(requests.single.path, '/api/timeslots');
      expect(requests.single.query, {'date': '2026-12-01'});
      expect(slots.single['capacity'], 8);
    });

    test('rejects a response that is not a list of objects', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({'not': 'a list'}));
      await expectLater(api.listSlots('2026-12-01'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    });

    test('gets one slot by id', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse(slot));
      await api.getSlot(3);
      expect(requests.single.path, '/api/timeslots/3');
    });
  });

  group('ServiceSlot', () {
    test('fromJson reads id, times, capacity, free seats and tables', () {
      final s = ServiceSlot.fromJson({
        'tsID': 3,
        'start_time': '2026-12-01 12:00',
        'end_time': '2026-12-01 13:30',
        'capacity': 10,
        'free_seats': 6,
        'tables': [{'table_no': 1, 'seats': 4}, {'table_no': 2, 'seats': 6}],
      });

      expect(s.id, 3);
      expect(s.capacity, 10);
      expect(s.freeSeats, 6);
      expect(s.tables.map((t) => t.toJson()), [
        {'table_no': 1, 'seats': 4},
        {'table_no': 2, 'seats': 6},
      ]);
      expect(s.hasLayout, isTrue);
    });

    test('start/end labels and duration in minutes', () {
      final s = ServiceSlot.fromJson(
          {'tsID': 1, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:30'});
      expect(s.startLabel, '12:00');
      expect(s.endLabel, '13:30');
      expect(s.durationMinutes, 90);
    });

    test('a slot without tables has no layout and capacity 0', () {
      final s = ServiceSlot.fromJson(
          {'tsID': 1, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:00', 'tables': []});
      expect(s.hasLayout, isFalse);
      expect(s.capacity, 0);
      expect(s.freeSeats, 0);
    });

    test('missing or malformed tables are treated as no layout', () {
      final s = ServiceSlot.fromJson(
          {'tsID': 1, 'start_time': '2026-12-01 12:00', 'end_time': '2026-12-01 13:00', 'tables': 'x'});
      expect(s.tables, isEmpty);
    });
  });

  group('TableDraft', () {
    test('converts to and from the JSON used by the API', () {
      final t = TableDraft.fromJson({'table_no': 4, 'seats': 6});
      expect(t.tableNo, 4);
      expect(t.seats, 6);
      expect(t.toJson(), {'table_no': 4, 'seats': 6});
    });
  });

  group('date formatting', () {
    test('formatYmd pads month and day (API format)', () {
      expect(formatYmd(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('formatLongDate shows weekday, day, month and year', () {
      expect(formatLongDate(DateTime(2026, 11, 6)), 'Friday, 6 Nov 2026');
    });
  });
}
