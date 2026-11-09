import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/medical_visit.dart';

abstract interface class VisitGateway {
  Future<List<MedicalVisit>> getVisits({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  });
}

class VisitApi implements VisitGateway {
  VisitApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<MedicalVisit>> getVisits({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/medical-visits',
    ).replace(queryParameters: {'start': _date(start), 'end': _date(end)});
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 20));
      _debugLog('GET /medical-visits -> HTTP ${response.statusCode}');

      if (response.statusCode == 401) {
        throw const VisitException(
          'Tu sesión expiró. Cierra sesión e ingresa nuevamente.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decoded is Map<String, dynamic> ? decoded : const {};
        throw VisitException(
          body['detail'] as String? ??
              body['error'] as String? ??
              'No fue posible cargar las visitas.',
        );
      }

      final rawItems = switch (decoded) {
        List<dynamic> value => value,
        Map<String, dynamic> value when value['results'] is List<dynamic> =>
          value['results'] as List<dynamic>,
        Map<String, dynamic> value when value['data'] is List<dynamic> =>
          value['data'] as List<dynamic>,
        _ => const <dynamic>[],
      };

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(MedicalVisit.fromJson)
          .where((visit) => visit.id > 0)
          .toList()
        ..sort((a, b) {
          final aDate = a.plannedStart ?? DateTime(2100);
          final bDate = b.plannedStart ?? DateTime(2100);
          return aDate.compareTo(bDate);
        });
    } on VisitException {
      rethrow;
    } on FormatException {
      throw const VisitException('El servidor devolvió datos inválidos.');
    } catch (error) {
      _debugLog('GET /medical-visits sin respuesta: ${error.runtimeType}');
      throw const VisitException(
        'No se pudo conectar con el servidor para cargar las visitas.',
      );
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[Mercurius/Visits] $message');
  }
}

class VisitException implements Exception {
  const VisitException(this.message);

  final String message;

  @override
  String toString() => message;
}
