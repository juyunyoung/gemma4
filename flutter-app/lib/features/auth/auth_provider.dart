import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import 'user_model.dart';

// 실제 서버 IP/Realm 은 .env 에서 주입 (빌드 시 --dart-define 사용)
// 예: flutter run --dart-define=KEYCLOAK_ISSUER=http://192.168.1.10:8080/realms/agent-realm
const String _kClientId =
    String.fromEnvironment('KEYCLOAK_CLIENT_ID', defaultValue: 'flutter-app');
const String _kRedirectUri = 'com.agentreport.app://callback';
const String _kIssuer = String.fromEnvironment(
  'KEYCLOAK_ISSUER',
  defaultValue: 'http://localhost:8080/realms/agent-realm',
);
const List<String> _kScopes = ['openid', 'profile', 'email', 'roles'];

final authProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<UserModel?> {
  late final FlutterAppAuth _appAuth;
  late final FlutterSecureStorage _storage;

  @override
  Future<UserModel?> build() async {
    _appAuth = const FlutterAppAuth();
    _storage = ref.watch(secureStorageProvider);
    return _tryRestoreSession();
  }

  Future<UserModel?> _tryRestoreSession() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;
    final role = await _storage.read(key: 'user_role') ?? 'reporter';
    final username = await _storage.read(key: 'username') ?? '';
    return UserModel(username: username, role: role, accessToken: token);
  }

  Future<void> login() async {
    state = const AsyncLoading();
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _kClientId,
          _kRedirectUri,
          issuer: _kIssuer,
          scopes: _kScopes,
        ),
      );

      if (result == null) {
        state = const AsyncData(null);
        return;
      }

      await _storage.write(key: 'access_token', value: result.accessToken);
      await _storage.write(key: 'refresh_token', value: result.refreshToken);

      // ID Token에서 claims 파싱 (간소화)
      final claims = _parseIdToken(result.idToken ?? '');
      final username = claims['preferred_username'] ?? '';
      final role = _extractRole(claims);

      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'user_role', value: role);

      state = AsyncData(UserModel(
        username: username,
        role: role,
        accessToken: result.accessToken ?? '',
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncData(null);
  }

  Map<String, dynamic> _parseIdToken(String token) {
    if (token.isEmpty) return {};
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      return jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _extractRole(Map<String, dynamic> claims) {
    final roles = (claims['realm_access']?['roles'] as List?)?.cast<String>();
    if (roles == null) return 'reporter';
    for (final r in ['admin', 'department_head', 'team_leader', 'reporter']) {
      if (roles.contains(r)) return r;
    }
    return 'reporter';
  }
}
