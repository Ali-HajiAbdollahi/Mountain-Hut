// MH-07 Reserve for an hiker — unit tests (hiker lookup API, HikerResult, debouncer, validators)
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/core/utils/debouncer.dart';
import 'package:client/core/utils/validators.dart';
import 'package:client/features/staff_portal/presentation/widgets/hiker_lookup_field.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.searchHikers', () {
    test('sends GET /api/staff/hikers with the query parameter', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'hikers': []}));
      await api.searchHikers('rossi');

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/staff/hikers');
      expect(requests.single.query, {'query': 'rossi'});
    });

    test('returns the list inside the "hikers" field', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse({
            'hikers': [
              {'uID': 1, 'name': 'Elena Rossi', 'email': 'elena@x.it', 'phone': '123'},
              {'uID': 2, 'name': 'Marco Rossi', 'email': 'marco@x.it', 'phone': null},
            ],
          }));
      final hikers = await api.searchHikers('rossi');
      expect(hikers.map((h) => h['uID']), [1, 2]);
    });

    test('a response without the "hikers" list becomes INVALID_RESPONSE', () async {
      final (:api, requests: _) = apiWith((_) => jsonResponse([]));
      await expectLater(api.searchHikers('rossi'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    });

    test('a non-employee gets the 403 from the server as an ApiException', () async {
      final (:api, requests: _) = apiWith((_) => errorResponse(403, 'FORBIDDEN', 'Employee account required'));
      await expectLater(api.searchHikers('rossi'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    });

    test('a query that is too short (400) becomes an ApiException with the server message', () async {
      final (:api, requests: _) = apiWith(
          (_) => errorResponse(400, 'VALIDATION_ERROR', 'Search query must contain at least 2 characters'));
      await expectLater(api.searchHikers('r'),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('at least 2'))));
    });
  });

  group('HikerResult', () {
    test('fromJson reads uID, name, email and phone', () {
      final h = HikerResult.fromJson({'uID': 5, 'name': 'Elena', 'email': 'e@x.it', 'phone': '123'});
      expect(h.uId, 5);
      expect(h.name, 'Elena');
      expect(h.email, 'e@x.it');
      expect(h.phone, '123');
    });

    test('subtitle joins email and phone, skipping the missing ones', () {
      expect(const HikerResult(uId: 1, name: 'A', email: 'a@x.it', phone: '123').subtitle, 'a@x.it · 123');
      expect(const HikerResult(uId: 1, name: 'A', email: 'a@x.it').subtitle, 'a@x.it');
      expect(const HikerResult(uId: 1, name: 'A', phone: '123').subtitle, '123');
      expect(const HikerResult(uId: 1, name: 'A').subtitle, '');
    });
  });

  group('Debouncer (lookup search)', () {
    // testWidgets is used only for its fake clock (tester.pump advances the timers).
    testWidgets('runs only the last action, 400 ms after the last call', (tester) async {
      final debouncer = Debouncer();
      addTearDown(debouncer.dispose);
      final runs = <String>[];

      debouncer.run(() => runs.add('ro'));
      await tester.pump(const Duration(milliseconds: 200));
      debouncer.run(() => runs.add('ros'));
      await tester.pump(const Duration(milliseconds: 399));
      expect(runs, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(runs, ['ros']);
    });

    testWidgets('dispose cancels the pending action', (tester) async {
      final debouncer = Debouncer();
      var ran = false;
      debouncer.run(() => ran = true);
      debouncer.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(ran, isFalse);
    });
  });

  group('Validators used by the "Add New Hiker" form', () {
    test('required rejects empty or blank values', () {
      expect(Validators.required('', fieldName: 'Name'), 'Name is required');
      expect(Validators.required('   ', fieldName: 'Name'), 'Name is required');
      expect(Validators.required('Elena', fieldName: 'Name'), isNull);
    });

    test('email requires a valid address', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('elena'), 'Enter a valid email address');
      expect(Validators.email('elena@hut.it'), isNull);
    });

    test('password requires at least 8 characters', () {
      expect(Validators.password('1234567'), 'Password must be at least 8 characters');
      expect(Validators.password('12345678'), isNull);
    });
  });
}
