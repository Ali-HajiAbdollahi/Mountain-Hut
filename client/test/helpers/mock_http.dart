// Runs the real MountainHutApi against a fake HTTP server (package:http MockClient).
import 'dart:convert';

import 'package:client/core/network/mountain_hut_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Recorded {
  Recorded(this.request);

  final http.Request request;

  String get method => request.method;
  String get path => request.url.path;
  Map<String, String> get query => request.url.queryParameters;
  Object? get json => request.body.isEmpty ? null : jsonDecode(request.body);
}

/// Creates a MountainHutApi whose HTTP client answers with [handler].
/// MountainHutApi builds its client with http.Client(), which runWithClient replaces.
({MountainHutApi api, List<Recorded> requests}) apiWith(
  http.Response Function(http.Request request) handler,
) {
  final requests = <Recorded>[];
  final api = http.runWithClient(
    MountainHutApi.new,
    () => MockClient((request) async {
      requests.add(Recorded(request));
      return handler(request);
    }),
  );
  return (api: api, requests: requests);
}

http.Response jsonResponse(Object body, [int status = 200, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

http.Response errorResponse(int status, String code, String message) =>
    jsonResponse({'error': {'code': code, 'message': message}}, status);
