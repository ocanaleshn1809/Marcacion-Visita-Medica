import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercurius/core/theme/app_theme.dart';
import 'package:mercurius/features/auth/presentation/auth_controller.dart';
import 'package:mercurius/features/auth/presentation/login_screen.dart';

import 'auth_controller_test.dart';

void main() {
  testWidgets('muestra validaciones cuando los campos están vacíos', (
    tester,
  ) async {
    final controller = AuthController(
      gateway: FakeAuthGateway(),
      sessionStore: MemorySessionStore(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(controller: controller),
      ),
    );

    expect(find.text('MERCURIUS'), findsOneWidget);
    expect(find.text('Recordar usuario'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('loginButton')));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
  });
}
