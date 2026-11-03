import 'package:http/http.dart' as http;

import 'api_client_stub.dart'
    if (dart.library.js_interop) 'api_client_web.dart'
    as platform;

http.Client createApiClient() => platform.createApiClient();

bool get isBrowserClient => platform.isBrowserClient;
