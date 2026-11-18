// MH-20 Register a hike — unit tests (API client, hike draft)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/validators.dart';
import 'package:client/features/hike_registration/domain/entities/hike_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

const _hike = {
  'destination': 'Chiaretto Lake',
  'route': 'via the east ridge',
  'departure_time': '2026-12-02 08:00',
  'expected_return': '2026-12-02 17:30',
  'waypoints': [{'name': 'Vizo Mozzo'}],
};

HikeDraft _draft({
  List<String> points = const ['Vizo Mozzo'],
  DateTime? departure,
  DateTime? expectedReturn,
}) =>
    HikeDraft(
      destination: 'Chiaretto Lake',
      routeDescription: 'via the east ridge',
      passagePoints: points,
      departureTime: departure ?? DateTime(2026, 12, 2, 8),
      expectedReturnTime: expectedReturn ?? DateTime(2026, 12, 2, 17, 30),
    );

void main() {
  group('MountainHutApi.registerHike', () {
    test('sends the hike with POST /api/hikes', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'hike': {'hID': 1, ..._hike}}, 201));
      await api.registerHike(_hike);

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/hikes');
      expect(requests.single.json, _hike);
    });

    test('returns the registered hike', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({'hike': {'hID': 7, 'uID': 2, ..._hike}}, 201));
      final hike = await api.registerHike(_hike);
      expect(hike, containsPair('hID', 7));
      expect(hike, containsPair('destination', 'Chiaretto Lake'));
    });

    test('invalid data (400) becomes an ApiException with the server message', () async {
      final (:api, requests: _) =
          apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'departure_time cannot be in the past'));
      await expectLater(
        api.registerHike(_hike),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'departure_time cannot be in the past')),
      );
    });

    test('without a session (401) or as an employee (403) the request is refused', () async {
      for (final (status, code) in [(401, 'UNAUTHENTICATED'), (403, 'FORBIDDEN')]) {
        final (:api, requests: _) = apiWith((_) => errorResponse(status, code, 'Not allowed'));
        await expectLater(api.registerHike(_hike),
            throwsA(isA<ApiException>().having((e) => e.status, 'status', status)));
      }
    });

    test('a response without the hike is reported as invalid', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({'status': 'ok'}, 201));
      await expectLater(api.registerHike(_hike),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    });
  });

  group('HikeDraft.toJson', () {
    test('sends only the fields the server stores', () {
      expect(_draft().toJson().keys.toSet(),
          {'destination', 'route', 'departure_time', 'expected_return', 'waypoints'});
    });

    test('formats the times as YYYY-MM-DD HH:mm, with leading zeros', () {
      final json = _draft(departure: DateTime(2027, 3, 5, 7, 5), expectedReturn: DateTime(2027, 3, 5, 9, 0)).toJson();
      expect(json['departure_time'], '2027-03-05 07:05');
      expect(json['expected_return'], '2027-03-05 09:00');
    });

    test('allows a return on the following day', () {
      final json = _draft(departure: DateTime(2026, 12, 2, 16), expectedReturn: DateTime(2026, 12, 3, 10)).toJson();
      expect(json['expected_return'], '2026-12-03 10:00');
    });

    test('sends the passage points in order, as {name}', () {
      expect(_draft(points: ['Old Bridge', 'Vizo Mozzo', 'Colle del Pas']).toJson()['waypoints'], [
        {'name': 'Old Bridge'},
        {'name': 'Vizo Mozzo'},
        {'name': 'Colle del Pas'},
      ]);
    });

    test('trims the passage points and leaves out the empty ones', () {
      expect(_draft(points: ['  Old Bridge ', '', '   ', 'Vizo Mozzo']).toJson()['waypoints'], [
        {'name': 'Old Bridge'},
        {'name': 'Vizo Mozzo'},
      ]);
      expect(_draft(points: []).toJson()['waypoints'], isEmpty);
    });
  });

  group('Validators.required (destination and route)', () {
    test('accepts any text that is not blank', () {
      expect(Validators.required('Chiaretto Lake', fieldName: 'Destination'), isNull);
    });

    test('rejects an empty or blank value, naming the field', () {
      expect(Validators.required('', fieldName: 'Destination'), 'Destination is required');
      expect(Validators.required('   ', fieldName: 'Route description'), 'Route description is required');
      expect(Validators.required(null, fieldName: 'Destination'), 'Destination is required');
    });
  });
}
