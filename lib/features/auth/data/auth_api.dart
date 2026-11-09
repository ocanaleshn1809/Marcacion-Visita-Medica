import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/auth_models.dart';

abstract interface class AuthGateway {
  Future<LoginResult> login({required String email, required String password});

  Future<SelectedUnitResult> selectUnit({
    required String temporaryToken,
    required UnitAccess access,
  });

  Future<void> logout(String accessToken);
}

class AuthApi implements AuthGateway {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final result = LoginResult.fromJson(response);
    if (result.accessToken.isEmpty) {
      throw const AuthException('El servidor no devolvió un token de acceso.');
    }
    return result;
  }

  @override
  Future<SelectedUnitResult> selectUnit({
    required String temporaryToken,
    required UnitAccess access,
  }) async {
    final response = await _post(
      '/auth/select-unit/',
      token: temporaryToken,
      body: {'unit_code': access.unitCode, 'role_code': access.roleCode},
    );
    final result = SelectedUnitResult.fromJson(response);
    if (result.accessToken.isEmpty) {
      throw const AuthException('No se pudo activar el espacio de trabajo.');
    }
    return result;
  }

  @override
  Future<void> logout(String accessToken) async {
    await _post('/auth/logout', token: accessToken, body: const {});
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      _debugLog('POST $path -> HTTP ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            decoded['detail'] as String? ??
            decoded['error'] as String? ??
            'No fue posible completar la solicitud.';
        _debugLog('POST $path rechazado: $message');
        throw AuthException(message);
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on FormatException {
      throw const AuthException('El servidor devolvió una respuesta inválida.');
    } catch (error) {
      _debugLog('POST $path sin respuesta: ${error.runtimeType}');
      throw const AuthException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[Mercurius/Auth] $message');
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
