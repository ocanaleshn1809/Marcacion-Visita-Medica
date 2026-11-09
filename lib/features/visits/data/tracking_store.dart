import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/medical_visit.dart';
import '../domain/tracking_models.dart';

abstract interface class TrackingStore {
  Future<String> installationIdentifier();
  Future<PendingTrackingSession?> readPending({required int ownerId});
  Future<void> savePending({
    required int ownerId,
    required PendingTrackingSession session,
  });
  Future<void> clearPending();
}

class SecureTrackingStore implements TrackingStore {
  const SecureTrackingStore();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _deviceKey = 'mercurius_installation_uuid';
  static const _pendingKey = 'mercurius_pending_tracking';

  @override
  Future<String> installationIdentifier() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final identifier = const Uuid().v4();
    await _storage.write(key: _deviceKey, value: identifier);
    return identifier;
  }

  @override
  Future<PendingTrackingSession?> readPending({required int ownerId}) async {
    final raw = await _storage.read(key: _pendingKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['owner_id'] != ownerId) return null;
      return PendingTrackingSession(
        visitId: json['visit_id'] as int,
        sessionUuid: json['session_uuid'] as String,
        checkInPointUuid: json['check_in_point_uuid'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        startLocation: GeoPoint.fromJson(
          json['start_location'] as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      await clearPending();
      return null;
    }
  }

  @override
  Future<void> savePending({
    required int ownerId,
    required PendingTrackingSession session,
  }) {
    return _storage.write(
      key: _pendingKey,
      value: jsonEncode({
        'owner_id': ownerId,
        'visit_id': session.visitId,
        'session_uuid': session.sessionUuid,
        'check_in_point_uuid': session.checkInPointUuid,
        'started_at': session.startedAt.toIso8601String(),
        'start_location': session.startLocation.toJson(),
      }),
    );
  }

  @override
  Future<void> clearPending() => _storage.delete(key: _pendingKey);
}
