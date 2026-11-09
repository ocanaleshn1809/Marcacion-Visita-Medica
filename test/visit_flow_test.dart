import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercurius/features/auth/domain/session_identity.dart';
import 'package:mercurius/features/visits/data/location_service.dart';
import 'package:mercurius/features/visits/data/tracking_api.dart';
import 'package:mercurius/features/visits/data/tracking_store.dart';
import 'package:mercurius/features/visits/data/visit_api.dart';
import 'package:mercurius/features/visits/domain/medical_visit.dart';
import 'package:mercurius/features/visits/domain/tracking_models.dart';
import 'package:mercurius/features/visits/presentation/visit_controller.dart';

void main() {
  test('obtiene el nombre del visitador desde el JWT', () {
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({'user_id': 34, 'full_name': 'Carlos Rivera'}),
          ),
        )
        .replaceAll('=', '');

    final identity = SessionIdentity.fromToken('header.$payload.signature');

    expect(identity.userId, 34);
    expect(identity.displayName, 'Carlos Rivera');
  });

  test('interpreta una visita del calendario', () {
    final visit = MedicalVisit.fromJson({
      'id': 152,
      'doctor': {'name1': 'Ana', 'last_name1': 'López'},
      'user': {'id': 34, 'full_name': 'Carlos Rivera'},
      'clinic': {'id': 22, 'name': 'Clínica Centro'},
      'start_date_plan': '2026-09-10T09:00:00-06:00',
      'end_date_plan': '2026-09-10T09:30:00-06:00',
      'status': 'Pendiente',
    });

    expect(visit.doctorName, 'Ana López');
    expect(visit.clinicName, 'Clínica Centro');
    expect(visit.canStart, isTrue);
  });

  test('inicia y finaliza el tracking de una visita con GPS', () async {
    final visit = MedicalVisit.fromJson({
      'id': 152,
      'doctor': {'full_name': 'Dra. Ana López'},
      'user': {'full_name': 'Carlos Rivera'},
      'start_date_plan': '2026-09-10T09:00:00-06:00',
      'end_date_plan': '2026-09-10T09:30:00-06:00',
      'status': 'Pendiente',
    });
    final controller = VisitController(
      gateway: FakeVisitGateway([visit]),
      trackingGateway: FakeTrackingGateway(),
      trackingStore: FakeTrackingStore(),
      locationGateway: FakeLocationGateway(),
      accessToken: 'token',
      userId: 34,
    );

    await controller.loadToday();
    expect(controller.visits, hasLength(1));

    expect(await controller.startVisit(visit), isTrue);
    expect(controller.activeVisit?.startLocation.latitude, 14.0723);

    final summary = await controller.finishVisit();
    expect(summary, isNotNull);
    expect(summary!.visit.id, 152);
    expect(summary.endLocation.longitude, -87.1921);
    expect(controller.activeVisit, isNull);
  });

  test('serializa la ubicación completa para tracking', () {
    const point = GeoPoint(
      latitude: 14.081527418245,
      longitude: -87.179143912345,
      accuracy: 16.2387,
      altitude: 960.127,
      speed: 0.567,
      heading: 180.555,
      locationSource: 'GPS',
      isMocked: false,
    );

    final json = point.toTrackingJson(pointUuid: 'point');

    expect(json['point_uuid'], 'point');
    expect(json['latitude'], 14.081527);
    expect(json['longitude'], -87.179144);
    expect(json['accuracy_meters'], 16.24);
    expect(json['altitude_meters'], 960.13);
    expect(json['speed_mps'], 0.57);
    expect(json['heading_degrees'], 180.56);
  });

  test('no restaura como activa una sesión que el backend rechazó', () async {
    final visit = MedicalVisit.fromJson({
      'id': 152,
      'doctor': {'full_name': 'Dra. Ana López'},
      'status': 'Pendiente',
    });
    final store = FakeTrackingStore()
      ..pending = PendingTrackingSession(
        visitId: 152,
        sessionUuid: 'session-rejected',
        checkInPointUuid: 'point-rejected',
        startedAt: DateTime(2026, 9, 11, 8),
        startLocation: const GeoPoint(
          latitude: 14.081527,
          longitude: -87.179144,
          accuracy: 16,
        ),
      );
    final controller = VisitController(
      gateway: FakeVisitGateway([visit]),
      trackingGateway: FakeTrackingGateway(),
      trackingStore: store,
      locationGateway: FakeLocationGateway(),
      accessToken: 'token',
      userId: 34,
    );

    await controller.loadToday();

    expect(controller.activeVisit, isNull);
  });

  test('incluye el desfase horario en fechas enviadas al backend', () {
    final encoded = iso8601WithOffset(DateTime.now());
    expect(encoded, matches(RegExp(r'(Z|[+-]\d\d:\d\d)$')));
  });
}

class FakeVisitGateway implements VisitGateway {
  FakeVisitGateway(this.visits);

  final List<MedicalVisit> visits;

  @override
  Future<List<MedicalVisit>> getVisits({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async => visits;
}

class FakeLocationGateway implements LocationGateway {
  @override
  Future<GeoPoint> currentLocation() async =>
      const GeoPoint(latitude: 14.0723, longitude: -87.1921, accuracy: 8);
}

class FakeTrackingGateway implements TrackingGateway {
  @override
  Future<TrackingSession> startTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String deviceIdentifier,
  }) async => TrackingSession(
    sessionUuid: sessionUuid,
    status: 'IN_PROGRESS',
    startedAt: capturedAt,
    checkIn: location,
  );

  @override
  Future<TrackingSession> finishTracking({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required String status,
  }) async => TrackingSession(
    sessionUuid: sessionUuid,
    status: status,
    startedAt: capturedAt.subtract(const Duration(minutes: 10)),
    finishedAt: capturedAt,
    checkIn: location,
    checkOut: location,
  );

  @override
  Future<TrackingSession> getTracking({
    required String accessToken,
    required int visitId,
  }) => throw const VisitException('Sin tracking');

  @override
  Future<void> rescheduleVisit({
    required String accessToken,
    required int visitId,
    required String sessionUuid,
    required String pointUuid,
    required DateTime capturedAt,
    required GeoPoint location,
    required RescheduleRequest request,
  }) async {}
}

class FakeTrackingStore implements TrackingStore {
  PendingTrackingSession? pending;

  @override
  Future<void> clearPending() async => pending = null;

  @override
  Future<String> installationIdentifier() async => 'installation-id';

  @override
  Future<PendingTrackingSession?> readPending({required int ownerId}) async =>
      pending;

  @override
  Future<void> savePending({
    required int ownerId,
    required PendingTrackingSession session,
  }) async => pending = session;
}
