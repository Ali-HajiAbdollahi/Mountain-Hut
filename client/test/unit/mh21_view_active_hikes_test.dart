// MH-21 View active hikes — unit tests (API client)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

final _hike = {
  'hID': 3,
  'hiker_name': 'Marco Bianchi',
  'destination': 'Chiaretto Lake',
  'route': 'via the east ridge',
  'expected_return': '2026-12-01 17:30',
  'waypoints': [
    {'position': 1, 'name': 'Old Bridge'},
    {'position': 2, 'name': 'Vizo Mozzo'},
  ],
};

void main() {
  group('MountainHutApi.listActiveHikes', () {
    test('asks for the active hikes with GET /api/hikes/active', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([]));
      await api.listActiveHikes();

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/hikes/active');
      expect(requests.single.query, isEmpty);
    });

    test('returns each hike with hiker, destination, route, expected return and waypoints', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([_hike]));
      final hikes = await api.listActiveHikes();

      expect(hikes.single, containsPair('hiker_name', 'Marco Bianchi'));
      expect(hikes.single, containsPair('expected_return', '2026-12-01 17:30'));
      expect((hikes.single['waypoints'] as List).map((w) => w['name']), ['Old Bridge', 'Vizo Mozzo']);
    });

    test('keeps the order of the server (earliest expected return first)', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([
            {..._hike, 'hID': 5, 'expected_return': '2026-12-01 11:00'},
            {..._hike, 'hID': 3, 'expected_return': '2026-12-01 17:30'},
          ]));
      expect((await api.listActiveHikes()).map((h) => h['hID']), [5, 3]);
    });

    test('nobody out returns an empty list', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([]));
      expect(await api.listActiveHikes(), isEmpty);
    });

    test('a hiker (403) or a visitor (401) gets an ApiException', () async {
      for (final (status, code) in [(403, 'FORBIDDEN'), (401, 'UNAUTHENTICATED')]) {
        final (:api, requests: _) = apiWith((_) => errorResponse(status, code, 'Not allowed'));
        await expectLater(api.listActiveHikes(), throwsA(isA<ApiException>().having((e) => e.status, 'status', status)));
      }
    });

    test('a busy database (503) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(503, 'DATABASE_BUSY', 'Please retry shortly'));
      await expectLater(api.listActiveHikes(),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Please retry shortly')));
    });
  });
}
