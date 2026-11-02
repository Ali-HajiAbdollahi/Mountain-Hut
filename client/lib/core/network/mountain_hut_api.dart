import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
  MountainHutApi() : _client = http.Client();

  final http.Client _client;

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
          case 'DELETE':
            return _client.delete(uri, headers: headers);
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }
      })().timeout(const Duration(seconds: 30));

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

  Future<void> logout() async {
    await _request('DELETE', ApiEndpoints.currentSession);
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

  Future<Map<String, dynamic>> checkAvailability({
    required String date,
    required String time,
    required int partySize,
  }) => _object(
    'GET',
    ApiEndpoints.availability,
    query: {'date': date, 'time': time, 'partySize': partySize.toString()},
  );

  Future<Map<String, dynamic>> book({
    required int slotId,
    required int people,
    List<Map<String, dynamic>> requirements = const [],
  }) => _object(
    'POST',
    ApiEndpoints.bookings,
    body: {'tsID': slotId, 'n_people': people, 'requirements': requirements},
  );

  Future<List<Map<String, dynamic>>> myBookings() =>
      _list(ApiEndpoints.bookings);

  Future<Map<String, dynamic>> booking(int id) =>
      _object('GET', ApiEndpoints.booking(id));

  Future<Map<String, dynamic>> resendConfirmation(int id) =>
      _object('POST', ApiEndpoints.confirmation(id), body: {});

  void close() => _client.close();
}
