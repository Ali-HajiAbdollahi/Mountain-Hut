// MH-08 Cancel a booking — unit tests (API client)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.cancelBooking', () {
    test('sends DELETE /api/bookings/:id without a body', () async {
      final (:api, :requests) = apiWith((_) => http.Response('', 204));
      await api.cancelBooking(7);

      expect(requests.single.method, 'DELETE');
      expect(requests.single.path, '/api/bookings/7');
      expect(requests.single.json, isNull);
    });

    test('completes on 204 No Content, without trying to read a JSON body', () async {
      final (:api, requests: _) = apiWith((_) => http.Response('', 204));
      await expectLater(api.cancelBooking(7), completes);
    });

    test('the booking of another hiker (404) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(404, 'NOT_FOUND', 'Booking not found'));
      await expectLater(
        api.cancelBooking(7),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.code, 'code', 'NOT_FOUND')
            .having((e) => e.message, 'message', 'Booking not found')),
      );
    });

    test('without a session the 401 becomes an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(401, 'UNAUTHENTICATED', 'Login required'));
      await expectLater(
        api.cancelBooking(7),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });

    test('sends the session cookie received at login', () async {
      final (:api, :requests) = apiWith((request) => request.url.path == '/api/sessions'
          ? jsonResponse({'uID': 1, 'role': 'hiker'}, 200, {'set-cookie': 'mh.sid=abc123; Path=/; HttpOnly'})
          : http.Response('', 204));
      await api.login('marco@mail.it', 'password123');
      await api.cancelBooking(7);

      expect(requests.last.request.headers['Cookie'], 'mh.sid=abc123');
    });
  });
}
