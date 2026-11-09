import 'medical_visit.dart';

class TrackingSession {
  const TrackingSession({
    required this.sessionUuid,
    required this.status,
    required this.startedAt,
    required this.checkIn,
    this.finishedAt,
    this.checkOut,
  });

  factory TrackingSession.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final checkInJson = _point(json['check_in'], points, pointType: 'CHECK_IN');
    final checkOutJson = _point(
      json['check_out'],
      points,
      pointType: 'CHECK_OUT',
    );
    return TrackingSession(
      sessionUuid: json['session_uuid']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startedAt:
          DateTime.tryParse(json['started_at_device']?.toString() ?? '') ??
          DateTime.now(),
      finishedAt: DateTime.tryParse(
        json['finished_at_device']?.toString() ?? '',
      ),
      checkIn: checkInJson == null ? null : GeoPoint.fromJson(checkInJson),
      checkOut: checkOutJson == null ? null : GeoPoint.fromJson(checkOutJson),
    );
  }

  final String sessionUuid;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final GeoPoint? checkIn;
  final GeoPoint? checkOut;

  bool get isInProgress => status == 'IN_PROGRESS';

  static Map<String, dynamic>? _point(
    dynamic preferred,
    Iterable<Map<String, dynamic>> points, {
    required String pointType,
  }) {
    if (preferred is Map<String, dynamic> && preferred.isNotEmpty) {
      return preferred;
    }
    for (final point in points) {
      if (point['point_type'] == pointType) return point;
    }
    return null;
  }
}

class PendingTrackingSession {
  const PendingTrackingSession({
    required this.visitId,
    required this.sessionUuid,
    required this.checkInPointUuid,
    required this.startedAt,
    required this.startLocation,
  });

  final int visitId;
  final String sessionUuid;
  final String checkInPointUuid;
  final DateTime startedAt;
  final GeoPoint startLocation;
}

class RescheduleRequest {
  const RescheduleRequest({
    required this.reason,
    required this.plannedStart,
    required this.plannedEnd,
  });

  final String reason;
  final DateTime plannedStart;
  final DateTime plannedEnd;
}
