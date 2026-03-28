import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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
import '../../screens/lesson/lesson_screen.dart';
import '../../screens/teacher/teacher_profile_screen.dart';
import '../../screens/packages/package_screen.dart';
import '../../models/category_model.dart';
import '../../screens/admin/users_management_screen.dart';
import '../../screens/admin/categories_management_screen.dart';
import '../../screens/admin/teachers_management_screen.dart';
import '../../screens/admin/bundles_management_screen.dart';
import '../../screens/admin/tips_management_screen.dart';
import '../../screens/admin/banners_management_screen.dart';
import '../../screens/admin/courses_management_screen.dart';
import '../../screens/admin/create_course_screen.dart';
import '../../screens/admin/lessons_management_screen.dart';
import '../../screens/admin/exams_management_screen.dart';
import '../../screens/admin/create_lesson_screen.dart';
import '../../screens/admin/subscriptions_management_screen.dart';
import '../../screens/admin/payment_receipts_screen.dart';
import '../../screens/admin/payment_settings_screen.dart';
import '../../screens/admin/notifications_management_screen.dart';
import '../../screens/admin/qr_management_screen.dart';
import '../../screens/admin/updates_management_screen.dart';
import '../../screens/admin/security_settings_screen.dart';
import '../../screens/admin/create_bundle_screen.dart';
import '../../screens/admin/create_tip_screen.dart';
import '../../screens/admin/course_enrollments_screen.dart';
import '../../screens/admin/teacher_enrollment_stats_screen.dart';
import '../../screens/admin/payment_receipt_detail_screen.dart';
import '../../screens/admin/financial_reports_screen.dart';
import '../../screens/teacher/create_exam_screen.dart';
import '../../screens/teacher/manage_questions_screen.dart';
import '../../screens/admin/teacher_requests_screen.dart';
import '../../models/bundle.dart';
import '../../models/tip.dart';

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
        final id = state.pathParameters['id']!;
        return CourseDetailsScreen(courseId: id);
      },
      routes: [
        GoRoute(
          path: 'content',
          builder: (context, state) {
            final courseId = state.pathParameters['id']!;
            // This will look for the course and open content
            return CourseDetailsScreen(courseId: courseId, startAtContent: true);
          },
        ),
        GoRoute(
          path: 'lesson/:lessonId',
          builder: (context, state) {
            final courseId = state.pathParameters['id']!;
            final lessonId = state.pathParameters['lessonId']!;
            return LessonScreen(courseId: courseId, lessonId: lessonId);
          },
        ),
      ],
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
      path: '/teacher/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TeacherProfileScreen(teacherId: id);
      },
    ),
    GoRoute(
      path: '/package/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PackageScreen(bundleId: id);
      },
    ),
    GoRoute(
      path: '/admin',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AdminDashboardScreen(),
      routes: [
        GoRoute(
          path: 'users',
          builder: (context, state) => const UsersManagementScreen(),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const CategoriesManagementScreen(),
        ),
        GoRoute(
          path: 'teachers',
          builder: (context, state) => const TeachersManagementScreen(),
        ),
        GoRoute(
          path: 'teacher-requests',
          builder: (context, state) => const TeacherRequestsScreen(),
        ),
        GoRoute(
          path: 'bundles',
          builder: (context, state) => const BundlesManagementScreen(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (context, state) => const CreateBundleScreen(),
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) {
                final bundle = state.extra as Bundle?;
                return CreateBundleScreen(bundle: bundle);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'tips',
          builder: (context, state) => const TipsManagementScreen(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (context, state) => const CreateTipScreen(),
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) {
                final tip = state.extra as Tip?;
                return CreateTipScreen(tip: tip);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'banners',
          builder: (context, state) => const BannersManagementScreen(),
        ),
        GoRoute(
          path: 'courses',
          builder: (context, state) {
            final instructorId = state.uri.queryParameters['instructorId'];
            return CoursesManagementScreen(instructorId: instructorId);
          },
          routes: [
            GoRoute(
              path: 'create',
              builder: (context, state) {
                final instructorId = state.uri.queryParameters['instructorId'];
                return CreateCourseScreen(preselectedInstructorId: instructorId);
              },
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final courseData = state.extra as Map<String, dynamic>?;
                return CreateCourseScreen(courseId: id, courseData: courseData);
              },
            ),
            GoRoute(
              path: ':courseId/lessons',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return LessonsManagementScreen(courseId: courseId, courseTitle: courseTitle);
              },
            ),
            GoRoute(
              path: ':courseId/exams',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return AdminExamsManagementScreen(courseId: courseId, courseTitle: courseTitle);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'lessons/create/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            return CreateLessonScreen(courseId: courseId);
          },
        ),
        GoRoute(
          path: 'lessons/edit/:lessonId',
          builder: (context, state) {
            final lessonId = state.pathParameters['lessonId']!;
            final courseId = state.uri.queryParameters['courseId'] ?? '';
            final lessonData = state.extra as Map<String, dynamic>?;
            return CreateLessonScreen(courseId: courseId, lessonId: lessonId, lessonData: lessonData);
          },
        ),
        GoRoute(
          path: 'subscriptions',
          builder: (context, state) => const SubscriptionsManagementScreen(),
          routes: [
            GoRoute(
              path: 'course/:courseId',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return CourseEnrollmentsScreen(courseId: courseId, courseTitle: courseTitle);
              },
            ),
            GoRoute(
              path: 'teacher/:teacherId',
              builder: (context, state) {
                final teacherId = state.pathParameters['teacherId']!;
                final teacherName = state.uri.queryParameters['name'] ?? '';
                final avatarUrl = state.uri.queryParameters['avatar'];
                return TeacherEnrollmentStatsScreen(
                  teacherId: teacherId,
                  teacherName: teacherName,
                  avatarUrl: avatarUrl,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'payments',
          builder: (context, state) => const PaymentReceiptsScreen(),
          routes: [
            GoRoute(
              path: 'detail/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return PaymentReceiptDetailScreen(receiptId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'payment-settings',
          builder: (context, state) => const PaymentSettingsScreen(),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) => const NotificationsManagementScreen(),
        ),
        GoRoute(
          path: 'qr',
          builder: (context, state) => const QrManagementScreen(),
        ),
        GoRoute(
          path: 'updates',
          builder: (context, state) => const UpdatesManagementScreen(),
        ),
        GoRoute(
          path: 'security',
          builder: (context, state) => const SecuritySettingsScreen(),
        ),
        GoRoute(
          path: 'reports/financial',
          builder: (context, state) => const FinancialReportsScreen(),
          routes: [
            GoRoute(
              path: 'preview',
              builder: (context, state) {
                final generator = state.extra as Future<Uint8List> Function(PdfPageFormat);
                return Scaffold(
                  appBar: AppBar(title: const Text('معاينة التقرير')),
                  body: PdfPreview(
                    build: generator,
                    canDebug: false,
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'exams/create',
          builder: (context, state) {
            final courseId = state.uri.queryParameters['courseId'] ?? '';
            final lessonId = state.uri.queryParameters['lessonId'];
            return CreateExamScreen(initialCourseId: courseId, lessonId: lessonId, loadAllCourses: true);
          },
        ),
        GoRoute(
          path: 'exams/questions/:examId',
          builder: (context, state) {
            final examId = state.pathParameters['examId']!;
            final examTitle = state.uri.queryParameters['title'] ?? '';
            return ManageQuestionsScreen(examId: examId, examTitle: examTitle);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const RegisterScreen(),
      routes: [
        GoRoute(
          path: 'complete',
          builder: (context, state) => const RegisterScreen(isCompletingProfile: true),
        ),
      ],
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
