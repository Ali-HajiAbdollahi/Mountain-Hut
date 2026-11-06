// MH-03 Receive confirmation — unit tests (API client)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi', () {
    test('booking(id) reads the details of one booking', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'bID': 12, 'reference': 'MH-12'}));
      final booking = await api.booking(12);

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/bookings/12');
      expect(booking['reference'], 'MH-12');
    });

    test('resendConfirmation sends POST /api/bookings/:id/confirmation with an empty body', () async {
      final (:api, :requests) = apiWith(
          (_) => jsonResponse({'bookingReference': 'MH-12', 'notification': {'status': 'accepted'}}));
      final result = await api.resendConfirmation(12);

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/bookings/12/confirmation');
      expect(requests.single.json, <String, dynamic>{});
      expect(result['notification'], {'status': 'accepted'});
    });

    test('the booking of another hiker is reported as not found', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(404, 'NOT_FOUND', 'Booking not found'));
      await expectLater(api.booking(99),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    });
  });
}
