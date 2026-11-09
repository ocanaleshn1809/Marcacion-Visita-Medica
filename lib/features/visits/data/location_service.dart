import 'package:geolocator/geolocator.dart';

import '../domain/medical_visit.dart';

abstract interface class LocationGateway {
  Future<GeoPoint> currentLocation();
}

class DeviceLocationService implements LocationGateway {
  @override
  Future<GeoPoint> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activa la ubicación del teléfono para registrar la visita.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Debes permitir el acceso a la ubicación para iniciar la visita.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
      );
    }

    try {
      final recentPosition = await Geolocator.getLastKnownPosition();
      if (recentPosition != null && _isRecentAndAccurate(recentPosition)) {
        return _toPoint(recentPosition, source: 'CACHED');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return _toPoint(position, source: 'GPS');
    } catch (_) {
      throw const LocationException(
        'No se pudo obtener tu ubicación. Intenta en un lugar con mejor señal.',
      );
    }
  }

  bool _isRecentAndAccurate(Position position) {
    final age = DateTime.now().difference(position.timestamp).abs();
    return age <= const Duration(minutes: 2) && position.accuracy <= 75;
  }

  GeoPoint _toPoint(Position position, {required String source}) => GeoPoint(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    altitude: position.altitude,
    speed: position.speed < 0 ? null : position.speed,
    heading: position.heading < 0 ? null : position.heading,
    locationSource: source,
    isMocked: position.isMocked,
  );
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
