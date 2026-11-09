import 'package:flutter_test/flutter_test.dart';
import 'package:mercurius/features/auth/domain/auth_models.dart';

void main() {
  test('interpreta la respuesta real con múltiples unidades y roles', () {
    final result = LoginResult.fromJson({
      'message': 'Login exitoso',
      'access_token': 'temporary-token',
      'requires_unit_selection': true,
      'units': [
        {
          'unit_code': 'AD-001',
          'unit_name': 'Administrator',
          'role_code': 'ADMIN',
          'role_name': 'Administrador',
        },
        {
          'unit_code': 'MV-001',
          'unit_name': 'Visita Médica',
          'role_code': 'MEDICAL_VISITOR',
          'role_name': 'Visitador Médico',
        },
        {
          'unit_code': 'MV-001',
          'unit_name': 'Visita Médica',
          'role_code': 'MEDICAL_COORDINATOR',
          'role_name': 'Coordinador Médico',
        },
      ],
    });

    expect(result.requiresUnitSelection, isTrue);
    expect(result.units, hasLength(3));
    expect(result.units[1].unitCode, 'MV-001');
    expect(result.units[1].roleCode, 'MEDICAL_VISITOR');
    expect(result.units[2].roleCode, 'MEDICAL_COORDINATOR');
  });
}
