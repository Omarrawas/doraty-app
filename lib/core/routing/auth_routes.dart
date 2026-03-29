import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes_names.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';

List<RouteBase> getAuthRoutes(GlobalKey<NavigatorState> parentKey) {
  return [
    GoRoute(
      path: AppRoutes.login,
      parentNavigatorKey: parentKey,
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      parentNavigatorKey: parentKey,
      builder: (context, state) => const RegisterScreen(),
      routes: [
        GoRoute(
          // e.g. /register/complete
          path: AppRoutes.registerComplete,
          builder: (context, state) =>
              const RegisterScreen(isCompletingProfile: true),
        ),
      ],
    ),
  ];
}
