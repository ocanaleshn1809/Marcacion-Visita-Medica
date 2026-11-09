import 'package:flutter_test/flutter_test.dart';
import 'package:mercurius/features/auth/data/auth_api.dart';
import 'package:mercurius/features/auth/data/session_store.dart';
import 'package:mercurius/features/auth/domain/auth_models.dart';
import 'package:mercurius/features/auth/presentation/auth_controller.dart';

void main() {
  group('AuthController', () {
    test('guarda la sesión de un usuario con un solo acceso', () async {
      final store = MemorySessionStore();
      final controller = AuthController(
        gateway: FakeAuthGateway(),
        sessionStore: store,
      );

      await controller.initialize();
      final success = await controller.signIn(
        email: 'visitador@empresa.com',
        password: 'Password123*',
        rememberUser: true,
      );

      expect(success, isTrue);
      expect(controller.status, AuthStatus.authenticated);
      expect(store.value?.accessToken, 'access-token');
      expect(store.value?.activeRole, 'VISITADOR');
      expect(store.rememberedEmail, 'visitador@empresa.com');
    });

    test('conserva el mensaje entregado por la API', () async {
      final controller = AuthController(
        gateway: FakeAuthGateway(fails: true),
        sessionStore: MemorySessionStore(),
      );

      await controller.initialize();
      final success = await controller.signIn(
        email: 'visitador@empresa.com',
        password: 'incorrecta',
      );

      expect(success, isFalse);
      expect(controller.status, AuthStatus.guest);
      expect(controller.errorMessage, 'Credenciales inválidas');
    });
  });
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.fails = false});

  final bool fails;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    if (fails) throw const AuthException('Credenciales inválidas');
    return const LoginResult(
      accessToken: 'access-token',
      requiresUnitSelection: false,
      units: [
        UnitAccess(
          unitCode: 'VISITA_MEDICA',
          unitName: 'Visita Médica',
          roleCode: 'VISITADOR',
          roleName: 'Visitador Médico',
        ),
      ],
    );
  }

  @override
  Future<void> logout(String accessToken) async {}

  @override
  Future<SelectedUnitResult> selectUnit({
    required String temporaryToken,
    required UnitAccess access,
  }) async {
    return const SelectedUnitResult(
      accessToken: 'selected-token',
      activeUnit: 'VISITA_MEDICA',
      activeRole: 'VISITADOR',
    );
  }
}

class MemorySessionStore implements SessionStore {
  UserSession? value;
  String? rememberedEmail;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<UserSession?> read() async => value;

  @override
  Future<String?> readRememberedEmail() async => rememberedEmail;

  @override
  Future<void> save(UserSession session) async => value = session;

  @override
  Future<void> saveRememberedEmail(String? email) async {
    rememberedEmail = email;
  }
}
