// MH-07 Reserve for an hiker — password management: API client calls for the forced change and the recovery
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/mock_http.dart';

void main() {
  group('MountainHutApi.changePassword', () {
    test('sends PUT /api/users/current/password with the current and the new password', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'uID': 5, 'must_change_password': false}));
      final user = await api.changePassword(currentPassword: 'old-password', newPassword: 'new-password');

      expect(requests.single.method, 'PUT');
      expect(requests.single.path, '/api/users/current/password');
      expect(requests.single.json, {'current_password': 'old-password', 'new_password': 'new-password'});
      expect(user['must_change_password'], false);
    });

    test('a wrong current password becomes an ApiException', () async {
      final (:api, requests: _) =
          apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'Current password is not correct'));
      await expectLater(
        api.changePassword(currentPassword: 'x', newPassword: 'new-password'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Current password is not correct')),
      );
    });
  });

  group('password recovery', () {
    test('requests a reset with POST /api/password-resets', () async {
      final (:api, :requests) = apiWith((_) => jsonResponse({'status': 'accepted'}, 202));
      await api.requestPasswordReset('marco@mail.it');

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/password-resets');
      expect(requests.single.json, {'email': 'marco@mail.it'});
    });

    test('sets the new password with POST /api/password-resets/confirm (no content answer)', () async {
      final (:api, :requests) = apiWith((_) => http.Response('', 204));
      await api.confirmPasswordReset(token: 'abc', newPassword: 'new-password');

      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/api/password-resets/confirm');
      expect(requests.single.json, {'token': 'abc', 'new_password': 'new-password'});
    });

    test('an expired or used token becomes an ApiException', () async {
      final (:api, requests: _) =
          apiWith((_) => errorResponse(400, 'VALIDATION_ERROR', 'Invalid or expired reset link'));
      await expectLater(
        api.confirmPasswordReset(token: 'old', newPassword: 'new-password'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('expired'))),
      );
    });
  });
}
