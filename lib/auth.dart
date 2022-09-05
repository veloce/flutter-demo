import 'dart:developer' as developer;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

const lichessClientId = 'lichess_flutter_demo';
const redirectUri = 'org.lichess.flutterdemo://login-callback';
const accountUrl = '$kLichessHost/api/account';

const _storage = FlutterSecureStorage();

class Auth {
  final _appAuth = FlutterAppAuth();

  Me? me;

  Future<void> init() async {
    try {
      final token = await _storage.read(key: lichessClientId);
      if (token != null) {
        await _getMyAccount();
      }
    } on Exception catch (e, s) {
      developer.log('Error on auth init: $e, $s');
    }
  }

  Future<void> login() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(AuthorizationTokenRequest(
        lichessClientId,
        redirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: '$kLichessHost/oauth', tokenEndpoint: '$kLichessHost/api/token'),
        scopes: ['board:play'],
      ));
      if (result != null) {
        developer.log('Got accessToken ${result.accessToken}');
        await _storage.write(key: lichessClientId, value: result.accessToken);
        await _getMyAccount();
      } else {
        throw Exception('Could not login');
      }
    } on Exception catch (e, s) {
      developer.log('Error on login: $e, $s');
    }
  }

  Future<void> logout() async {
    if (me != null) {
      final authHttp = AuthClient(http.Client());
      try {
        await authHttp.delete(Uri.parse('$kLichessHost/api/token'));
        await _storage.delete(key: lichessClientId);
        me = null;
      } finally {
        authHttp.close();
      }
    }
  }

  Future<void> _getMyAccount() async {
    final authHttp = AuthClient(http.Client());
    try {
      final uri = Uri.parse('$kLichessHost/api/account');
      developer.log('Calling: ' + uri.toString());
      final response = await authHttp.get(uri);

      developer.log('Response code: ' + response.statusCode.toString());
      if (response.statusCode == 200) {
        me = Me.fromJson(jsonDecode(response.body));
      }
    } finally {
      authHttp.close();
    }
  }
}

class AuthClient extends http.BaseClient {
  final http.Client _inner;

  AuthClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _storage.read(key: lichessClientId);
    request.headers['Authorization'] = 'Bearer ' + (token ?? '');
    developer.log('http authorization header: ' + request.headers['Authorization']!);
    return _inner.send(request);
  }
}

class Me {
  final String id;
  final String username;

  const Me({
    required this.id,
    required this.username,
  });

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'],
      username: json['username'],
    );
  }
}
