// MH-01 Book a table — unit tests (API client, repository, sign-in validators)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/validators.dart';
import 'package:client/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/fakes.dart';
import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.book', () {
    test('sends POST /api/bookings with tsID, n_people and requirements as JSON', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {'bID': 1}}, 201));
      await api.book(slotId: 3, people: 4);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/bookings');
      expect(request.request.headers['Content-Type'], startsWith('application/json'));
      expect(request.json, {'tsID': 3, 'n_people': 4, 'requirements': []});
    });

    test('turns a 409 error body into an ApiException with code and message', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(409, 'CONFLICT', 'Not enough free seats'));
      await expectLater(
        api.book(slotId: 3, people: 40),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'CONFLICT')
            .having((e) => e.message, 'message', 'Not enough free seats')),
      );
    });

    test('reports an invalid response when the server does not return JSON', () async {
      final (:api, requests: _) = apiWith((_) => http.Response('<html>oops</html>', 502));
      await expectLater(api.book(slotId: 3, people: 2),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    });

    test('sends the session cookie received at login, so the hiker is authenticated', () async {
      final (:api, :requests) = apiWith((request) => request.url.path == '/api/sessions'
          ? jsonResponse({'uID': 1, 'role': 'hiker'}, 200, {'set-cookie': 'mh.sid=abc123; Path=/; HttpOnly'})
          : jsonResponse({'booking': {}}, 201));

      await api.login('marco@mail.it', 'password123');
      await api.book(slotId: 3, people: 2);

      expect(requests.first.json, {'email': 'marco@mail.it', 'password': 'password123'});
      expect(requests.last.request.headers['Cookie'], 'mh.sid=abc123');
    });
  });

  group('BookingRepositoryImpl', () {
    test('forwards slot, party size and requirements to the API', () async {
      final api = FakeApi()..bookResponse = {'booking': {'bID': 5}};
      final response = await BookingRepositoryImpl(api).createBooking(
        slotId: 3,
        partySize: 4,
        requirements: [{'description': 'vegan', 'allergy': false}],
      );

      expect(response, {'booking': {'bID': 5}});
      expect(api.called('book').single.args, {
        'slotId': 3,
        'people': 4,
        'requirements': [{'description': 'vegan', 'allergy': false}],
      });
    });
  });

  group('Validators (a registered hiker is required to book)', () {
    test('email is required and must look like an email', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('marco@mail'), 'Enter a valid email address');
      expect(Validators.email(' marco@mail.it '), isNull);
    });

    test('password must have at least 8 characters, like the backend', () {
      expect(Validators.password(null), 'Password is required');
      expect(Validators.password('1234567'), 'Password must be at least 8 characters');
      expect(Validators.password('12345678'), isNull);
    });

    test('required rejects blank values', () {
      expect(Validators.required('   ', fieldName: 'Name'), 'Name is required');
      expect(Validators.required('Marco'), isNull);
    });
  });
}
