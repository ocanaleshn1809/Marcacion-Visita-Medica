import 'package:flutter/foundation.dart';

import '../data/auth_api.dart';
import '../data/session_store.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  initializing,
  guest,
  submitting,
  selectingUnit,
  authenticated,
}

class AuthController extends ChangeNotifier {
  AuthController({required this.gateway, required this.sessionStore});

  final AuthGateway gateway;
  final SessionStore sessionStore;

  AuthStatus status = AuthStatus.initializing;
  UserSession? session;
  List<UnitAccess> availableUnits = const [];
  String? errorMessage;
  String? rememberedEmail;
  String? _temporaryToken;
  String? _pendingEmail;
  bool _pendingRememberUser = false;

  bool get isBusy => status == AuthStatus.submitting;

  Future<void> initialize() async {
    try {
      final storedData = await Future.wait<Object?>([
        sessionStore.read(),
        sessionStore.readRememberedEmail(),
      ]);
      session = storedData[0] as UserSession?;
      rememberedEmail = storedData[1] as String?;
      status = session == null ? AuthStatus.guest : AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.guest;
    }
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberUser = false,
  }) async {
    errorMessage = null;
    _pendingEmail = email.trim();
    _pendingRememberUser = rememberUser;
    status = AuthStatus.submitting;
    notifyListeners();
    try {
      final result = await gateway.login(
        email: _pendingEmail!,
        password: password,
      );
      if (result.requiresUnitSelection || result.units.length > 1) {
        _temporaryToken = result.accessToken;
        availableUnits = result.units;
        status = AuthStatus.selectingUnit;
        notifyListeners();
        return true;
      }

      final access = result.units.firstOrNull;
      await _completeSession(
        UserSession(
          accessToken: result.accessToken,
          activeUnit: access?.unitCode,
          activeRole: access?.roleCode,
        ),
      );
      return true;
    } on AuthException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No fue posible iniciar sesión.';
    }
    status = AuthStatus.guest;
    _pendingEmail = null;
    _pendingRememberUser = false;
    notifyListeners();
    return false;
  }

  Future<bool> chooseUnit(UnitAccess access) async {
    final token = _temporaryToken;
    if (token == null) return false;
    errorMessage = null;
    status = AuthStatus.submitting;
    notifyListeners();
    try {
      final result = await gateway.selectUnit(
        temporaryToken: token,
        access: access,
      );
      await _completeSession(
        UserSession(
          accessToken: result.accessToken,
          activeUnit: result.activeUnit,
          activeRole: result.activeRole,
        ),
      );
      return true;
    } on AuthException catch (error) {
      errorMessage = error.message;
      status = AuthStatus.selectingUnit;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final token = session?.accessToken;
    if (token != null) {
      try {
        await gateway.logout(token);
      } catch (_) {
        // La sesión local debe cerrarse aunque el servidor no responda.
      }
    }
    await sessionStore.clear();
    session = null;
    availableUnits = const [];
    _temporaryToken = null;
    _pendingEmail = null;
    _pendingRememberUser = false;
    errorMessage = null;
    status = AuthStatus.guest;
    notifyListeners();
  }

  Future<void> _completeSession(UserSession value) async {
    if (_pendingRememberUser) {
      await sessionStore.save(value);
      await sessionStore.saveRememberedEmail(_pendingEmail);
      rememberedEmail = _pendingEmail;
    } else {
      await sessionStore.clear();
      await sessionStore.saveRememberedEmail(null);
      rememberedEmail = null;
    }
    session = value;
    _temporaryToken = null;
    _pendingEmail = null;
    _pendingRememberUser = false;
    availableUnits = const [];
    status = AuthStatus.authenticated;
    notifyListeners();
  }
}
