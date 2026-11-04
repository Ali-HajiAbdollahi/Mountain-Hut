// MH-02 Define slot capacity — unit tests (API client only: the staff UI, MH-35/MH-36,
// is not implemented yet, so there are no integration tests for this story)
import 'package:client/core/network/mountain_hut_api.dart';
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
}
