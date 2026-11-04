// MH-04 Check availability — unit tests (API client)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.checkAvailability', () {
    test('sends date, time and party size as query parameters', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'available': true, 'allocation': []}));
      await api.checkAvailability(date: '2026-12-01', time: '12:00', partySize: 6);

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/availability');
      expect(requests.single.query, {'date': '2026-12-01', 'time': '12:00', 'partySize': '6'});
    });

    test('is public: no cookie is sent when nobody has logged in', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'available': false, 'allocation': []}));
      await api.checkAvailability(date: '2026-12-01', time: '12:00', partySize: 2);
      expect(requests.single.request.headers.containsKey('Cookie'), isFalse);
    });

    test('returns the allocation of seats over the tables', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({
            'available': true,
            'allocation': [{'table_no': 1, 'seats': 2}, {'table_no': 2, 'seats': 4}],
          }));
      final result = await api.checkAvailability(date: '2026-12-01', time: '12:00', partySize: 6);
      expect(result['allocation'], hasLength(2));
    });

    test('invalid parameters (400) become an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'time must use HH:mm format'));
      await expectLater(
        api.checkAvailability(date: '2026-12-01', time: '12', partySize: 2),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'time must use HH:mm format')),
      );
    });
  });
}
