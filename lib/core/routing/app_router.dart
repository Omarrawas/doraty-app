import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/category_model.dart';

import '../services/auth_service.dart';
import 'routes_names.dart';
import 'auth_routes.dart';
import 'admin_routes.dart';
import 'course_routes.dart';

import '../../screens/splash/splash_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/explore/explore_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/tips/all_tips_screen.dart';
import '../../screens/categories/subjects_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/packages/all_packages_screen.dart';
import '../../screens/teacher/teachers_list_screen.dart';
import '../../screens/teacher/teacher_dashboard_screen.dart';
import '../../screens/courses/courses_list_screen.dart';
import '../../screens/help/faq_screen.dart';
import '../../screens/settings/privacy_policy_screen.dart';
import '../../screens/settings/terms_conditions_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/profile/order_history_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/categories/category_courses_screen.dart';
import '../../screens/teacher/teacher_profile_screen.dart';
import '../../screens/packages/package_screen.dart';
import '../../screens/error_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.root,
  
  // -- Error Handling --
  errorBuilder: (context, state) => const ErrorScreen(),

  // -- Route Guards (Protection) --
  redirect: (context, state) {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAuthenticated = authService.isAuthenticated;
      final role = authService.userProfile?['role'] ?? 'student';

      final path = state.uri.path;

      final isAuthRoute = path.startsWith(AppRoutes.login) ||
          path.startsWith(AppRoutes.register);

      final isAdminRoute = path.startsWith(AppRoutes.admin);

      final isProtectedProfileRoute = path.startsWith(AppRoutes.profile) ||
          path.startsWith(AppRoutes.favorites) ||
          path.startsWith(AppRoutes.myCourses) ||
          path.startsWith(AppRoutes.orders) ||
          path.startsWith(AppRoutes.notifications);

      // 1- Prevent unauthenticated users from accessing protected sections
      if (!isAuthenticated) {
        if (isAdminRoute ||
            isProtectedProfileRoute ||
            path.startsWith(AppRoutes.teacherDashboard)) {
          return AppRoutes.login;
        }
      }

      // 2- Prevent authenticated users from visiting auth pages
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.root; // redirect to home
      }

      // 3- Admin Protection
      if (isAdminRoute && role != 'admin' && role != 'owner' && role != 'super_admin') {
        // Allow teachers to access specific management routes
        final bool isTeacherAllowedRoute = path.startsWith('/admin/courses') ||
            path.startsWith('/admin/exams') ||
            path.startsWith('/admin/lessons') ||
            path.startsWith('/admin/results') ||
            path.startsWith('/admin/subscribers') ||
            path.startsWith('/admin/subscriptions/teacher') ||
            path.startsWith('/admin/reports/financial');

        if (role == 'teacher' && isTeacherAllowedRoute) {
          return null;
        }

        // Here we could throw them to an unauthorized error page, or home
        return AppRoutes.root; 
      }

      // 4- Teacher Dashboard Protection
      if (path.startsWith(AppRoutes.teacherDashboard) && 
          role != 'teacher' && role != 'admin' && role != 'super_admin' && role != 'owner') {
        return AppRoutes.root;
      }

      return null;
    } catch (_) {
      // In case provider isn't mounted yet or issues occur
      return null;
    }
  },

  routes: [
    GoRoute(
      path: AppRoutes.splash,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),

    // ShellRoute for Bottom Navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return MainScreen(routeState: state, child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.root,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.courses,
          builder: (context, state) {
            final categoryId = state.uri.queryParameters['categoryId'];
            final filter = state.uri.queryParameters['filter'];
            return ExploreScreen(
              initialFilter: categoryId ?? filter,
              showBackButton: categoryId != null || filter != null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.tips,
          builder: (context, state) => const AllTipsScreen(
              showAppBar: false, isVisible: true, showCloseButton: false),
        ),
        GoRoute(
          path: AppRoutes.topics,
          builder: (context, state) => const SubjectsScreen(showBackButton: false),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // Sub Routes Extracted
    ...getAuthRoutes(rootNavigatorKey),
    ...getCourseRoutes(rootNavigatorKey),
    ...getAdminRoutes(rootNavigatorKey),

    // Other Global Screen Routes
    GoRoute(
      path: '/category/:slug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final slug = state.pathParameters['slug'];
        if (slug == null) return const ErrorScreen();

        return CategoryCoursesScreen(
          category: CategoryModel(id: slug, name: '', slug: slug),
        );
      },
    ),
    GoRoute(
      path: '/tip/:idOrSlug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['idOrSlug'];
        if (id == null || id.isEmpty) return const ErrorScreen();
        return AllTipsScreen(initialTipId: id);
      },
    ),
    GoRoute(
      path: '/teacher/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null) return const ErrorScreen();
        return TeacherProfileScreen(teacherId: id);
      },
    ),
    GoRoute(
      path: '/package/:idOrSlug',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['idOrSlug'];
        if (id == null || id.isEmpty) return const ErrorScreen();
        
        final extra = state.extra;
        if (extra is Map<String, dynamic> && extra.containsKey('bundle')) {
          return PackageScreen(bundle: extra['bundle']);
        }
        
        return PackageScreen(bundleId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.settings,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.teachers,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TeachersListScreen(),
    ),
    GoRoute(
      path: AppRoutes.packages,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => AllPackagesScreen(),
    ),
    GoRoute(
      path: AppRoutes.faq,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => FAQScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: AppRoutes.terms,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TermsConditionsScreen(),
    ),
    GoRoute(
      path: AppRoutes.favorites,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => FavoritesScreen(),
    ),
    GoRoute(
      path: AppRoutes.orders,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const OrderHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.teacherDashboard,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TeacherDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.myCourses,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => CoursesListScreen(showBackButton: true),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
