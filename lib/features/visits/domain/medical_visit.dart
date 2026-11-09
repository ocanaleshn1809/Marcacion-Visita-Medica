class MedicalVisit {
  const MedicalVisit({
    required this.id,
    required this.doctorName,
    required this.visitorName,
    required this.status,
    required this.plannedStart,
    required this.plannedEnd,
    this.clinicName,
    this.specialtyName,
    this.notes,
    this.trackingSummary,
  });

  factory MedicalVisit.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'];
    final user = json['user'];
    final clinic = json['clinic'];
    final specialty = json['specialty'];
    final isSpecial = json['is_special_event'] as bool? ?? false;

    return MedicalVisit(
      id: _asInt(json['id']),
      doctorName: isSpecial
          ? _text(json['special_event_name']) ?? 'Evento especial'
          : _personName(doctor) ?? 'Médico sin nombre',
      visitorName: _personName(user) ?? '',
      clinicName: _entityName(clinic),
      specialtyName: _entityName(specialty),
      status: _text(json['status']) ?? 'Pendiente',
      plannedStart: DateTime.tryParse(
        json['start_date_plan']?.toString() ?? '',
      ),
      plannedEnd: DateTime.tryParse(json['end_date_plan']?.toString() ?? ''),
      notes: _text(json['notes']),
      trackingSummary: json['tracking_summary'] is Map<String, dynamic>
          ? TrackingSummary.fromJson(
              json['tracking_summary'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final int id;
  final String doctorName;
  final String visitorName;
  final String? clinicName;
  final String? specialtyName;
  final String status;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final String? notes;
  final TrackingSummary? trackingSummary;

  bool get canStart =>
      status.toLowerCase() == 'pendiente' && trackingSummary == null;

  MedicalVisit withTrackingSummary(TrackingSummary summary) => MedicalVisit(
    id: id,
    doctorName: doctorName,
    visitorName: visitorName,
    status: status,
    plannedStart: plannedStart,
    plannedEnd: plannedEnd,
    clinicName: clinicName,
    specialtyName: specialtyName,
    notes: notes,
    trackingSummary: summary,
  );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String? _entityName(dynamic entity) {
    if (entity is String) return _text(entity);
    if (entity is Map<String, dynamic>) {
      return _text(entity['name']) ?? _text(entity['full_name']);
    }
    return null;
  }

  static String? _personName(dynamic person) {
    if (person is String) return _text(person);
    if (person is! Map<String, dynamic>) return null;
    final fullName = _text(person['full_name']);
    if (fullName != null) return fullName;
    final parts = [
      _text(person['name1']),
      _text(person['name2']),
      _text(person['last_name1']),
      _text(person['last_name2']),
    ].whereType<String>();
    final name = parts.join(' ');
    return name.isEmpty ? null : name;
  }
}

class TrackingSummary {
  const TrackingSummary({
    required this.sessionUuid,
    required this.status,
    this.startedAtDevice,
    this.finishedAtDevice,
  });

  factory TrackingSummary.fromJson(Map<String, dynamic> json) {
    return TrackingSummary(
      sessionUuid: json['session_uuid']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startedAtDevice: DateTime.tryParse(
        json['started_at_device']?.toString() ?? '',
      ),
      finishedAtDevice: DateTime.tryParse(
        json['finished_at_device']?.toString() ?? '',
      ),
    );
  }

  final String sessionUuid;
  final String status;
  final DateTime? startedAtDevice;
  final DateTime? finishedAtDevice;

  bool get isInProgress => status == 'IN_PROGRESS';
}

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.locationSource = 'GPS',
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String locationSource;
  final bool isMocked;

  Map<String, dynamic> toTrackingJson({required String pointUuid}) => {
    'point_uuid': pointUuid,
    'latitude': _rounded(latitude, 6),
    'longitude': _rounded(longitude, 6),
    'accuracy_meters': _bounded(accuracy, 0, 999999.99, 2),
    'altitude_meters': _nullableBounded(altitude, -9999999.99, 9999999.99, 2),
    'speed_mps': _nullableBounded(speed, 0, 999999.99, 2),
    'heading_degrees': _nullableBounded(heading, 0, 360, 2),
    'location_source': locationSource,
    'is_mocked': isMocked,
  };

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'location_source': locationSource,
    'is_mocked': isMocked,
  };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    latitude: _double(json['latitude']),
    longitude: _double(json['longitude']),
    accuracy: _double(json['accuracy'] ?? json['accuracy_meters']),
    altitude: _nullableDouble(json['altitude'] ?? json['altitude_meters']),
    speed: _nullableDouble(json['speed'] ?? json['speed_mps']),
    heading: _nullableDouble(json['heading'] ?? json['heading_degrees']),
    locationSource: json['location_source']?.toString() ?? 'GPS',
    isMocked: json['is_mocked'] as bool? ?? false,
  );

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  static double _rounded(double value, int decimals) {
    if (!value.isFinite) return 0;
    return double.parse(value.toStringAsFixed(decimals));
  }

  static double _bounded(
    double value,
    double minimum,
    double maximum,
    int decimals,
  ) {
    if (!value.isFinite) return minimum;
    return _rounded(value.clamp(minimum, maximum).toDouble(), decimals);
  }

  static double? _nullableBounded(
    double? value,
    double minimum,
    double maximum,
    int decimals,
  ) {
    if (value == null || !value.isFinite) return null;
    return _bounded(value, minimum, maximum, decimals);
  }
}

class ActiveVisit {
  const ActiveVisit({
    required this.visit,
    required this.startedAt,
    required this.startLocation,
    required this.sessionUuid,
  });

  final MedicalVisit visit;
  final DateTime startedAt;
  final GeoPoint startLocation;
  final String sessionUuid;
}

class VisitSummary {
  const VisitSummary({
    required this.visit,
    required this.startedAt,
    required this.finishedAt,
    required this.startLocation,
    required this.endLocation,
  });

  final MedicalVisit visit;
  final DateTime startedAt;
  final DateTime finishedAt;
  final GeoPoint startLocation;
  final GeoPoint endLocation;
}
