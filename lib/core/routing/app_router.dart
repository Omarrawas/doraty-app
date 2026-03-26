import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../screens/courses/course_details_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/explore/explore_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/tips/all_tips_screen.dart';
import '../../screens/categories/subjects_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/teacher/teachers_list_screen.dart';
import '../../screens/packages/all_packages_screen.dart';
import '../../screens/splash/splash_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),

    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return MainScreen(child: child, routeState: state);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/courses',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(
          path: '/tips',
          builder: (context, state) => const AllTipsScreen(showAppBar: false, isVisible: true, showCloseButton: false),
        ),
        GoRoute(
          path: '/topics',
          builder: (context, state) => const SubjectsScreen(showBackButton: false),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/course/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        return CourseDetailsScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/admin',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => RegisterScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SettingsScreen(),
    ),
    GoRoute(
      path: '/teachers',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TeachersListScreen(),
    ),
    GoRoute(
      path: '/packages',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => AllPackagesScreen(),
    ),
  ],
);
