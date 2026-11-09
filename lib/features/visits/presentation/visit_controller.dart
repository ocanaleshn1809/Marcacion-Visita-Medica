import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/location_service.dart';
import '../data/tracking_api.dart';
import '../data/tracking_store.dart';
import '../data/visit_api.dart';
import '../domain/medical_visit.dart';
import '../domain/tracking_models.dart';

class VisitController extends ChangeNotifier {
  VisitController({
    required this.gateway,
    required this.trackingGateway,
    required this.trackingStore,
    required this.locationGateway,
    required this.accessToken,
    required this.userId,
  });

  final VisitGateway gateway;
  final TrackingGateway trackingGateway;
  final TrackingStore trackingStore;
  final LocationGateway locationGateway;
  final String accessToken;
  final int userId;

  List<MedicalVisit> visits = const [];
  ActiveVisit? activeVisit;
  bool isLoading = false;
  bool isCapturingLocation = false;
  String? errorMessage;

  Future<void> loadToday() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final now = DateTime.now();
    try {
      visits = await gateway.getVisits(
        accessToken: accessToken,
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day + 1),
      );
      activeVisit = null;
      await _restoreActiveVisit();
    } on VisitException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No fue posible cargar las visitas de hoy.';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> startVisit(MedicalVisit visit) async {
    if (activeVisit != null || isCapturingLocation || !visit.canStart) {
      return false;
    }
    isCapturingLocation = true;
    errorMessage = null;
    notifyListeners();
    try {
      final stored = await trackingStore.readPending(ownerId: userId);
      final pending = stored?.visitId == visit.id
          ? stored!
          : await _createPending(visit);
      final deviceIdentifier = await trackingStore.installationIdentifier();
      final session = await trackingGateway.startTracking(
        accessToken: accessToken,
        visitId: visit.id,
        sessionUuid: pending.sessionUuid,
        pointUuid: pending.checkInPointUuid,
        capturedAt: pending.startedAt,
        location: pending.startLocation,
        deviceIdentifier: deviceIdentifier,
      );
      activeVisit = ActiveVisit(
        visit: visit,
        startedAt: session.startedAt,
        startLocation: session.checkIn ?? pending.startLocation,
        sessionUuid: session.sessionUuid.isEmpty
            ? pending.sessionUuid
            : session.sessionUuid,
      );
      return true;
    } on LocationException catch (error) {
      errorMessage = error.message;
      return false;
    } on VisitException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'No fue posible iniciar el tracking de la visita.';
      return false;
    } finally {
      isCapturingLocation = false;
      notifyListeners();
    }
  }

  Future<VisitSummary?> finishVisit() async {
    final current = activeVisit;
    if (current == null || isCapturingLocation) return null;
    isCapturingLocation = true;
    errorMessage = null;
    notifyListeners();
    try {
      final endLocation = await locationGateway.currentLocation();
      final finishedAt = DateTime.now();
      final session = await trackingGateway.finishTracking(
        accessToken: accessToken,
        visitId: current.visit.id,
        sessionUuid: current.sessionUuid,
        pointUuid: const Uuid().v4(),
        capturedAt: finishedAt,
        location: endLocation,
        status: 'COMPLETED',
      );
      final summary = VisitSummary(
        visit: current.visit,
        startedAt: session.startedAt,
        finishedAt: session.finishedAt ?? finishedAt,
        startLocation: session.checkIn ?? current.startLocation,
        endLocation: session.checkOut ?? endLocation,
      );
      activeVisit = null;
      visits = visits
          .map(
            (visit) => visit.id == current.visit.id
                ? visit.withTrackingSummary(
                    TrackingSummary(
                      sessionUuid: current.sessionUuid,
                      status: 'COMPLETED',
                      startedAtDevice: summary.startedAt,
                      finishedAtDevice: summary.finishedAt,
                    ),
                  )
                : visit,
          )
          .toList();
      await trackingStore.clearPending();
      return summary;
    } on LocationException catch (error) {
      errorMessage = error.message;
      return null;
    } on VisitException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'No fue posible finalizar el tracking de la visita.';
      return null;
    } finally {
      isCapturingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> rescheduleActiveVisit(RescheduleRequest request) async {
    final current = activeVisit;
    if (current == null || isCapturingLocation) return false;
    isCapturingLocation = true;
    errorMessage = null;
    notifyListeners();
    try {
      final endLocation = await locationGateway.currentLocation();
      await trackingGateway.rescheduleVisit(
        accessToken: accessToken,
        visitId: current.visit.id,
        sessionUuid: current.sessionUuid,
        pointUuid: const Uuid().v4(),
        capturedAt: DateTime.now(),
        location: endLocation,
        request: request,
      );
      activeVisit = null;
      await trackingStore.clearPending();
      return true;
    } on LocationException catch (error) {
      errorMessage = error.message;
      return false;
    } on VisitException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'No fue posible reagendar la visita.';
      return false;
    } finally {
      isCapturingLocation = false;
      notifyListeners();
    }
  }

  Future<PendingTrackingSession> _createPending(MedicalVisit visit) async {
    final location = await locationGateway.currentLocation();
    final pending = PendingTrackingSession(
      visitId: visit.id,
      sessionUuid: const Uuid().v4(),
      checkInPointUuid: const Uuid().v4(),
      startedAt: DateTime.now(),
      startLocation: location,
    );
    await trackingStore.savePending(ownerId: userId, session: pending);
    return pending;
  }

  Future<void> _restoreActiveVisit() async {
    final pending = await trackingStore.readPending(ownerId: userId);
    final summaryVisit = _findVisit(
      (visit) => visit.trackingSummary?.isInProgress ?? false,
    );
    final visitId = pending?.visitId ?? summaryVisit?.id;
    if (visitId == null) return;
    final visit = _findVisit((visit) => visit.id == visitId);
    if (visit == null) return;

    try {
      final session = await trackingGateway.getTracking(
        accessToken: accessToken,
        visitId: visit.id,
      );
      if (!session.isInProgress) {
        if (pending != null) await trackingStore.clearPending();
        return;
      }
      final location = session.checkIn ?? pending?.startLocation;
      if (location == null) return;
      activeVisit = ActiveVisit(
        visit: visit,
        startedAt: session.startedAt,
        startLocation: location,
        sessionUuid: session.sessionUuid,
      );
    } on VisitException {
      if (pending == null || summaryVisit?.id != pending.visitId) return;
      activeVisit = ActiveVisit(
        visit: visit,
        startedAt: pending.startedAt,
        startLocation: pending.startLocation,
        sessionUuid: pending.sessionUuid,
      );
    }
  }

  MedicalVisit? _findVisit(bool Function(MedicalVisit visit) matches) {
    for (final visit in visits) {
      if (matches(visit)) return visit;
    }
    return null;
  }
}
