// MH-09 Repeat a weekly schedule — unit tests (API client, ISO week helpers)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/iso_week.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.repeatWeek', () {
    test('sends source and target week with POST /api/timeslots/repeat-week', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'slotIds': [10, 11], 'replacedCount': 0}, 201));
      await api.repeatWeek(sourceWeek: '2026-12-07', targetWeek: '2026-12-14');

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/timeslots/repeat-week');
      expect(requests.single.json, {'source_week': '2026-12-07', 'target_week': '2026-12-14'});
    });

    test('returns how many slots were copied', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({'slotIds': [10, 11, 12], 'replacedCount': 2}, 201));
      expect(await api.repeatWeek(sourceWeek: '2026-12-07', targetWeek: '2026-12-14'), 3);
    });

    test('a target week with reservations (409) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) =>
          errorResponse(409, 'CONFLICT', 'The target week has reservations: it cannot be replaced'));
      await expectLater(
        api.repeatWeek(sourceWeek: '2026-12-07', targetWeek: '2026-12-14'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.message, 'message', 'The target week has reservations: it cannot be replaced')),
      );
    });

    test('an empty source week (400) becomes an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'Source week has no slots'));
      await expectLater(
        api.repeatWeek(sourceWeek: '2026-12-07', targetWeek: '2026-12-14'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Source week has no slots')),
      );
    });

    test('a response without the list of copied slots is reported as invalid', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({'replacedCount': 0}, 201));
      await expectLater(
        api.repeatWeek(sourceWeek: '2026-12-07', targetWeek: '2026-12-14'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')),
      );
    });
  });

  group('isoWeekStart', () {
    test('a Monday is the start of its own week', () {
      expect(isoWeekStart(DateTime(2026, 12, 7)), DateTime(2026, 12, 7));
    });

    test('any other day goes back to the Monday of its week', () {
      expect(isoWeekStart(DateTime(2026, 12, 9)), DateTime(2026, 12, 7));
      expect(isoWeekStart(DateTime(2026, 12, 13)), DateTime(2026, 12, 7));
    });

    test('works across months and years', () {
      expect(isoWeekStart(DateTime(2026, 12, 2)), DateTime(2026, 11, 30));
      expect(isoWeekStart(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });

    test('ignores the time of day', () {
      expect(isoWeekStart(DateTime(2026, 12, 9, 18, 45)), DateTime(2026, 12, 7));
    });
  });

  group('isoWeekEndExclusive', () {
    test('is the Monday of the following week', () {
      expect(isoWeekEndExclusive(DateTime(2026, 12, 7)), DateTime(2026, 12, 14));
      expect(isoWeekEndExclusive(DateTime(2026, 12, 28)), DateTime(2027, 1, 4));
    });

    test('stays at midnight across a clock change', () {
      expect(isoWeekEndExclusive(DateTime(2027, 3, 22)), DateTime(2027, 3, 29));
    });
  });
}
