import 'package:http/http.dart' as http;

http.Client createApiClient() => http.Client();

bool get isBrowserClient => false;
