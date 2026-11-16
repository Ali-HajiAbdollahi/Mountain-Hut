import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

class MountainHutApi {
  MountainHutApi() : _client = createApiClient();

  final http.Client _client;
  String? _sessionCookie;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiEndpoints.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (!isBrowserClient && _sessionCookie != null) 'Cookie': _sessionCookie!,
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    try {
      final response = await (() {
        switch (method) {
          case 'GET':
            return _client.get(uri, headers: headers);
          case 'POST':
            return _client.post(uri, headers: headers, body: encodedBody);
          case 'PUT':
            return _client.put(uri, headers: headers, body: encodedBody);
          case 'PATCH':
            return _client.patch(uri, headers: headers, body: encodedBody);
          case 'DELETE':
            return _client.delete(uri, headers: headers);
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }
      })().timeout(const Duration(seconds: 30));

      _storeSessionCookie(response.headers['set-cookie']);
      if (response.statusCode == 204) return null;

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          response.statusCode,
          'INVALID_RESPONSE',
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = data is Map ? data['error'] : null;

        throw ApiException(
          response.statusCode,
          error is Map
              ? error['code']?.toString() ?? 'HTTP_ERROR'
              : 'HTTP_ERROR',
          error is Map
              ? error['message']?.toString() ?? 'Request failed.'
              : 'Request failed.',
        );
      }

      return data;
    } on TimeoutException {
      throw const ApiException(
        0,
        'TIMEOUT',
        'The request timed out. Check whether the operation succeeded '
            'before trying again.',
      );
    }
  }

  void _storeSessionCookie(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return;
    final cookie = setCookie.split(';').first.trim();
    if (cookie.isEmpty) return;

    final separator = cookie.indexOf('=');
    if (separator <= 0) return;
    final name = cookie.substring(0, separator);
    final value = cookie.substring(separator + 1);
    final current = (_sessionCookie ?? '')
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && !item.startsWith('$name='))
        .toList();
    if (value.isNotEmpty) current.add(cookie);
    _sessionCookie = current.isEmpty ? null : current.join('; ');
  }

  Future<Map<String, dynamic>> _object(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final data = await _request(method, path, body: body, query: query);

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        200,
        'INVALID_RESPONSE',
        'Expected a JSON object.',
      );
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> _list(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _request('GET', path, query: query);

    if (data is! List || data.any((item) => item is! Map<String, dynamic>)) {
      throw const ApiException(
        200,
        'INVALID_RESPONSE',
        'Expected a JSON array of objects.',
      );
    }

    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> health() => _object('GET', ApiEndpoints.health);

  Future<Map<String, dynamic>> login(String email, String password) => _object(
    'POST',
    ApiEndpoints.sessions,
    body: {'email': email, 'password': password},
  );

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) => _object(
    'POST',
    ApiEndpoints.users,
    body: {'name': name, 'email': email, 'phone': phone, 'password': password},
  );

  Future<Map<String, dynamic>> currentUser() =>
      _object('GET', ApiEndpoints.currentSession);

  /// Changes the password of the signed-in user; the returned user has
  /// `must_change_password` cleared.
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _object(
    'PUT',
    ApiEndpoints.currentPassword,
    body: {'current_password': currentPassword, 'new_password': newPassword},
  );

  /// The server answers in the same way whether the email is registered or not.
  Future<void> requestPasswordReset(String email) async {
    await _request('POST', ApiEndpoints.passwordResets, body: {'email': email});
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      ApiEndpoints.passwordResetConfirm,
      body: {'token': token, 'new_password': newPassword},
    );
  }

  Future<void> logout() async {
    await _request('DELETE', ApiEndpoints.currentSession);
    _sessionCookie = null;
  }

  Future<List<Map<String, dynamic>>> listSlots(String date) =>
      _list(ApiEndpoints.timeslots, query: {'date': date});

  Future<Map<String, dynamic>> getSlot(int id) =>
      _object('GET', ApiEndpoints.timeslot(id));

  Future<Map<String, dynamic>> createSlot({
    required String startTime,
    required String endTime,
    List<Map<String, dynamic>>? tables,
    int? copyFromTsId,
  }) {
    if ((tables == null) == (copyFromTsId == null)) {
      throw ArgumentError('Provide tables OR copyFromTsId.');
    }

    return _object(
      'POST',
      ApiEndpoints.timeslots,
      body: {
        'start_time': startTime,
        'end_time': endTime,
        'tables': ?tables,
        'copy_from_tsID': ?copyFromTsId,
      },
    );
  }

  Future<Map<String, dynamic>> defineTables(
    int slotId, {
    List<Map<String, dynamic>>? tables,
    int? copyFromTsId,
  }) {
    if ((tables == null) == (copyFromTsId == null)) {
      throw ArgumentError('Provide tables OR copyFromTsId.');
    }

    return _object(
      'PUT',
      ApiEndpoints.slotTables(slotId),
      body: {'tables': ?tables, 'copy_from_tsID': ?copyFromTsId},
    );
  }

  Future<Map<String, dynamic>> publishSlotMenu(int slotId, String menu) =>
      _object('PUT', ApiEndpoints.slotMenu(slotId), body: {'menu': menu});

  Future<List<Map<String, dynamic>>> recentMenus(String before) =>
      _list('${ApiEndpoints.timeslots}/menus/recent', query: {'before': before});

  Future<int> repeatWeek({
    required String sourceWeek,
    required String targetWeek,
  }) async {
    final response = await _object(
      'POST',
      ApiEndpoints.repeatWeek,
      body: {'source_week': sourceWeek, 'target_week': targetWeek},
    );
    final slotIds = response['slotIds'];
    if (slotIds is! List || slotIds.any((id) => id is! num)) {
      throw const ApiException(
        200,
        'INVALID_RESPONSE',
        'Expected replicated slot IDs.',
      );
    }
    return slotIds.length;
  }

  Future<Map<String, dynamic>> checkAvailability({
    required String date,
    required String time,
    required int partySize,
  }) => _object(
    'GET',
    ApiEndpoints.availability,
    query: {'date': date, 'time': time, 'partySize': partySize.toString()},
  );

  /// The API accepts a requirement only as `{n_people?, description, allergy}`: `n_people` is the
  /// number of people of the party concerned (1..party size) and is left out when not specified.
  /// Any other key would be rejected with "Unexpected field".
  static List<Map<String, dynamic>> requirementsPayload(
    List<Map<String, dynamic>> requirements,
  ) => [
    for (final requirement in requirements)
      {
        'n_people': ?requirement['n_people'],
        'description': requirement['description'],
        'allergy': requirement['allergy'] == true,
      },
  ];

  Future<Map<String, dynamic>> book({
    required int slotId,
    required int people,
    List<Map<String, dynamic>> requirements = const [],
  }) => _object(
    'POST',
    ApiEndpoints.bookings,
    body: {
      'tsID': slotId,
      'n_people': people,
      'requirements': requirementsPayload(requirements),
    },
  );

  Future<List<Map<String, dynamic>>> myBookings() =>
      _list(ApiEndpoints.bookings);

  Future<Map<String, dynamic>> booking(int id) =>
      _object('GET', ApiEndpoints.booking(id));

  Future<Map<String, dynamic>> updateBooking(
    int id, {
    int? slotId,
    int? people,
    List<Map<String, dynamic>>? requirements,
  }) => _object(
    'PATCH',
    ApiEndpoints.booking(id),
    body: {
      'tsID': ?slotId,
      'n_people': ?people,
      'requirements': ?(requirements == null
          ? null
          : requirementsPayload(requirements)),
    },
  );

  Future<void> cancelBooking(int id) async {
    await _request('DELETE', ApiEndpoints.booking(id));
  }

  Future<Map<String, dynamic>> resendConfirmation(int id) =>
      _object('POST', ApiEndpoints.confirmation(id), body: {});

    Future<List<Map<String, dynamic>>> searchHikers(String query) async {
    final data = await _request(
      'GET',
      '/staff/hikers',
      query: {'query': query},
    );
    if (data is! Map || data['hikers'] is! List) {
      throw const ApiException(200, 'INVALID_RESPONSE', 'Expected hikers array.');
    }
    return (data['hikers'] as List).cast<Map<String, dynamic>>();
  }

    Future<Map<String, dynamic>> createStaffBooking({
    required Map<String, dynamic> hiker,
    required int slotId,
    required int people,
    List<Map<String, dynamic>> requirements = const [],
  }) =>
      _object('POST', ApiEndpoints.staffBookings, body: {
        'hiker': hiker,
        'tsID': slotId,
        'n_people': people,
        'requirements': requirementsPayload(requirements),
      });

  void close() => _client.close();
}