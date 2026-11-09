import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/medical_visit.dart';
import '../domain/tracking_models.dart';
import 'visit_api.dart';

abstract interface class TrackingGateway {
  Future<TrackingSession> startTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String deviceIdentifier,
  });

  Future<TrackingSession> finishTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String status,
  });

  Future<TrackingSession> getTracking({
    required String accessToken,
    required int visitId,
  });

  Future<void> rescheduleVisit({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required RescheduleRequest request,
  });
}

class TrackingApi implements TrackingGateway {
  TrackingApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<TrackingSession> startTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String deviceIdentifier,
  }) async {
    final response = await _post(
      '$_baseUrl/medical-visits/$visitId/tracking/start',
      accessToken,
      {
        'session_uuid': sessionUuid,
        'captured_at_device': iso8601WithOffset(capturedAt),
        'location': location.toTrackingJson(pointUuid: pointUuid),
        'device_identifier': deviceIdentifier,
        'app_version': AppConfig.appVersion,
      },
    );
    return _trackingSession(response);
  }

  @override
  Future<TrackingSession> finishTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String status,
  }) async {
    final response = await _post(
      '$_baseUrl/medical-visits/$visitId/tracking/finish',
      accessToken,
      {
        'session_uuid': sessionUuid,
        'status': status,
        'captured_at_device': iso8601WithOffset(capturedAt),
        'location': location.toTrackingJson(pointUuid: pointUuid),
      },
    );
    return _trackingSession(response);
  }

  @override
  Future<TrackingSession> getTracking({
    required String accessToken,
    required int visitId,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/medical-visits/$visitId/tracking'),
            headers: _headers(accessToken),
          )
          .timeout(const Duration(seconds: 20));
      _debugLog('GET tracking/$visitId -> HTTP ${response.statusCode}');
      return _trackingSession(_decodeResponse(response));
    } on VisitException {
      rethrow;
    } catch (error) {
      _debugLog('GET tracking sin respuesta: ${error.runtimeType}');
      throw const VisitException(
        'No se pudo consultar el tracking de la visita.',
      );
    }
  }

  @override
  Future<void> rescheduleVisit({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required RescheduleRequest request,
  }) async {
    await _post('$_baseUrl/medical-visits/reschedule/$visitId', accessToken, {
      'rescheduled_reason': request.reason,
      'start_date_plan': iso8601WithOffset(request.plannedStart),
      'end_date_plan': iso8601WithOffset(request.plannedEnd),
      'tracking': {
        'session_uuid': sessionUuid,
        'captured_at_device': iso8601WithOffset(capturedAt),
        'location': location.toTrackingJson(pointUuid: pointUuid),
      },
    });
  }

  Future<Map<String, dynamic>> _post(
    String url,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: _headers(accessToken),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      _debugLog('POST ${Uri.parse(url).path} -> HTTP ${response.statusCode}');
      return _decodeResponse(response);
    } on VisitException {
      rethrow;
    } catch (error) {
      _debugLog('POST tracking sin respuesta: ${error.runtimeType}');
      throw const VisitException(
        'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = body['errors'];
      final error = body['error'];
      if (_containsLocationError(error) || _containsLocationError(errors)) {
        throw const VisitException(
          'El servidor rechazó los datos GPS. Intenta capturar la ubicación nuevamente.',
        );
      }
      throw VisitException(
        error?.toString() ??
            body['detail']?.toString() ??
            (errors is Map && errors.isNotEmpty
                ? errors.values.first.toString()
                : 'No fue posible registrar el tracking.'),
      );
    }
    return body;
  }

  bool _containsLocationError(dynamic value) {
    if (value is Map) {
      return value.keys.any((key) => key.toString() == 'location') ||
          value.values.any(_containsLocationError);
    }
    if (value is Iterable) return value.any(_containsLocationError);
    final text = value?.toString().toLowerCase() ?? '';
    return text.contains('latitude') ||
        text.contains('longitude') ||
        text.contains('accuracy_meters') ||
        text.contains('altitude_meters');
  }

  TrackingSession _trackingSession(Map<String, dynamic> body) {
    final raw = body['tracking_session'];
    if (raw is! Map<String, dynamic>) {
      throw const VisitException(
        'El servidor no devolvió la sesión de tracking esperada.',
      );
    }
    return TrackingSession.fromJson(raw);
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[Mercurius/Tracking] $message');
  }
}

String iso8601WithOffset(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${local.toIso8601String()}$sign$hours:$minutes';
}
