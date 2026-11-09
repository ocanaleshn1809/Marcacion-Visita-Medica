import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/session_store.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';

class MercuriusApp extends StatefulWidget {
  const MercuriusApp({super.key, this.authController});

  final AuthController? authController;

  @override
  State<MercuriusApp> createState() => _MercuriusAppState();
}

class _MercuriusAppState extends State<MercuriusApp> {
  late final AuthController _authController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.authController == null;
    _authController =
        widget.authController ??
        AuthController(
          gateway: AuthApi(),
          sessionStore: const SecureSessionStore(),
        );
    _authController.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mercurius',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          return switch (_authController.status) {
            AuthStatus.initializing => const _LaunchScreen(),
            AuthStatus.authenticated => HomeScreen(controller: _authController),
            _ => LoginScreen(controller: _authController),
          };
        },
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
