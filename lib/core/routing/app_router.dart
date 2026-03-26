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
import '../../screens/packages/all_packages_screen.dart';
import '../../screens/teacher/teachers_list_screen.dart';
import '../../screens/teacher/teacher_dashboard_screen.dart';
import '../../screens/courses/courses_list_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/help/faq_screen.dart';
import '../../screens/settings/privacy_policy_screen.dart';
import '../../screens/settings/terms_conditions_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/notifications_screen.dart';

import '../../screens/categories/category_courses_screen.dart';
import '../../models/category_model.dart';

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
        return MainScreen(routeState: state, child: child);
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
      path: '/category/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        // CategoryCoursesScreen needs a CategoryModel, so we pass slug as a fallback id
        return CategoryCoursesScreen(
          category: CategoryModel(id: slug, name: '', slug: slug),
        );
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
    GoRoute(
      path: '/faq',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => FAQScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TermsConditionsScreen(),
    ),
    GoRoute(
      path: '/favorites',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => FavoritesScreen(),
    ),
    GoRoute(
      path: '/teacher_dashboard',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TeacherDashboardScreen(),
    ),
    GoRoute(
      path: '/my_courses',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => CoursesListScreen(showBackButton: true),
    ),
    GoRoute(
      path: '/cart',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => CartScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
