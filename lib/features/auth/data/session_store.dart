import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_models.dart';

abstract interface class SessionStore {
  Future<UserSession?> read();
  Future<void> save(UserSession session);
  Future<void> clear();
  Future<String?> readRememberedEmail();
  Future<void> saveRememberedEmail(String? email);
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _tokenKey = 'mercurius_access_token';
  static const _unitKey = 'mercurius_active_unit';
  static const _roleKey = 'mercurius_active_role';
  static const _rememberedEmailKey = 'mercurius_remembered_email';

  @override
  Future<UserSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;
    final context = await Future.wait<String?>([
      _storage.read(key: _unitKey),
      _storage.read(key: _roleKey),
    ]);
    return UserSession(
      accessToken: token,
      activeUnit: context[0],
      activeRole: context[1],
    );
  }

  @override
  Future<void> save(UserSession session) async {
    await Future.wait<void>([
      _storage.write(key: _tokenKey, value: session.accessToken),
      _storage.write(key: _unitKey, value: session.activeUnit),
      _storage.write(key: _roleKey, value: session.activeRole),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _unitKey),
      _storage.delete(key: _roleKey),
    ]);
  }

  @override
  Future<String?> readRememberedEmail() =>
      _storage.read(key: _rememberedEmailKey);

  @override
  Future<void> saveRememberedEmail(String? email) =>
      _storage.write(key: _rememberedEmailKey, value: email);
}
