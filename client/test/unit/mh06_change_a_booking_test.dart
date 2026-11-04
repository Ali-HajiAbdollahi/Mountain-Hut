// MH-06 Change a booking — unit tests (API client)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.updateBooking', () {
    test('sends PATCH /api/bookings/:id with every changed field', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}));
      await api.updateBooking(7, slotId: 4, people: 5, requirements: [{'description': 'vegan', 'allergy': false}]);

      expect(requests.single.method, 'PATCH');
      expect(requests.single.path, '/api/bookings/7');
      expect(requests.single.json, {
        'tsID': 4,
        'n_people': 5,
        'requirements': [{'description': 'vegan', 'allergy': false}],
      });
    });

    test('omits the fields that are not changed', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}));
      await api.updateBooking(7, people: 3);
      expect(requests.single.json, {'n_people': 3});
    });

    test('a change refused by the 48-hour rule (409) becomes an ApiException', () async {
      final (:api, requests: _) = apiWith((_) =>
          errorResponse(409, 'CONFLICT', 'Booking changes must be made at least 48 hours before the meal'));
      await expectLater(
        api.updateBooking(7, people: 3),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.message, 'message', contains('48 hours'))),
      );
    });
  });

  group('MountainHutApi.myBookings', () {
    test('reads the bookings of the logged-in hiker', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse([{'bID': 7}, {'bID': 8}]));
      final bookings = await api.myBookings();

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/bookings');
      expect(bookings, hasLength(2));
    });

    test('without a session the 401 becomes an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(401, 'UNAUTHENTICATED', 'Login required'));
      await expectLater(api.myBookings(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    });
  });
}
