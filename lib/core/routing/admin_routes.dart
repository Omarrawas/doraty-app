import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'routes_names.dart';
import '../../models/bundle.dart';
import '../../models/tip.dart';
import '../../screens/error_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/users_management_screen.dart';
import '../../screens/admin/categories_management_screen.dart';
import '../../screens/admin/teachers_management_screen.dart';
import '../../screens/admin/teacher_detail_screen.dart';
import '../../screens/admin/teacher_requests_screen.dart';
import '../../screens/admin/bundles_management_screen.dart';
import '../../screens/admin/create_bundle_screen.dart';
import '../../screens/admin/tips_management_screen.dart';
import '../../screens/admin/create_tip_screen.dart';
import '../../screens/admin/banners_management_screen.dart';
import '../../screens/admin/courses_management_screen.dart';
import '../../screens/admin/create_course_screen.dart';
import '../../screens/admin/lessons_management_screen.dart';
import '../../screens/admin/exams_management_screen.dart';
import '../../screens/admin/create_lesson_screen.dart';
import '../../screens/admin/subscriptions_management_screen.dart';
import '../../screens/admin/course_enrollments_screen.dart';
import '../../screens/admin/teacher_enrollment_stats_screen.dart';
import '../../screens/admin/payment_receipts_screen.dart';
import '../../screens/admin/payment_receipt_detail_screen.dart';
import '../../screens/admin/payment_settings_screen.dart';
import '../../screens/admin/notifications_management_screen.dart';
import '../../screens/admin/qr_management_screen.dart';
import '../../screens/admin/updates_management_screen.dart';
import '../../screens/admin/security_settings_screen.dart';
import '../../screens/admin/financial_reports_screen.dart';
import '../../screens/teacher/create_exam_screen.dart';
import '../../screens/teacher/manage_questions_screen.dart';

List<RouteBase> getAdminRoutes(GlobalKey<NavigatorState> parentKey) {
  return [
    GoRoute(
      path: AppRoutes.admin,
      parentNavigatorKey: parentKey, // Force admin screens out of bottom nav shell
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
          routes: [
            GoRoute(
              path: 'detail/:id',
              builder: (context, state) {
                final id = state.pathParameters['id'];
                if (id == null) return const ErrorScreen();
                final teacherData = state.extra as Map<String, dynamic>?;
                return TeacherDetailAdminScreen(
                  teacherId: id,
                  teacherData: teacherData,
                );
              },
            ),
          ],
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
                // Fallback implemented
                final id = state.pathParameters['id'];
                if (id == null || id.isEmpty) return const ErrorScreen();
                
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
                final id = state.pathParameters['id'];
                if (id == null || id.isEmpty) return const ErrorScreen();

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
                final id = state.pathParameters['id'];
                if (id == null) return const ErrorScreen();

                final courseData = state.extra as Map<String, dynamic>?;
                return CreateCourseScreen(courseId: id, courseData: courseData);
              },
            ),
            GoRoute(
              path: ':courseId/lessons',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId'];
                if (courseId == null) return const ErrorScreen();

                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return LessonsManagementScreen(
                    courseId: courseId, courseTitle: courseTitle);
              },
            ),
            GoRoute(
              path: ':courseId/exams',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId'];
                if (courseId == null) return const ErrorScreen();

                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return AdminExamsManagementScreen(
                    courseId: courseId, courseTitle: courseTitle);
              },
            ),
          ],
        ),
        // Moved from parent route to internal admin lessons
        GoRoute(
          path: 'lessons/create/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId'];
            if (courseId == null) return const ErrorScreen();
            
            return CreateLessonScreen(courseId: courseId);
          },
        ),
        GoRoute(
          path: 'lessons/edit/:lessonId',
          builder: (context, state) {
            final lessonId = state.pathParameters['lessonId'];
            if (lessonId == null) return const ErrorScreen();

            final courseId = state.uri.queryParameters['courseId'] ?? '';
            final lessonData = state.extra as Map<String, dynamic>?;
            return CreateLessonScreen(
                courseId: courseId, lessonId: lessonId, lessonData: lessonData);
          },
        ),
        GoRoute(
          path: 'subscriptions',
          builder: (context, state) => const SubscriptionsManagementScreen(),
          routes: [
            GoRoute(
              path: 'course/:courseId',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId'];
                if (courseId == null) return const ErrorScreen();
                
                final courseTitle = state.uri.queryParameters['title'] ?? '';
                return CourseEnrollmentsScreen(
                    courseId: courseId, courseTitle: courseTitle);
              },
            ),
            GoRoute(
              path: 'teacher/:teacherId',
              builder: (context, state) {
                final teacherId = state.pathParameters['teacherId'];
                if (teacherId == null) return const ErrorScreen();

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
                final id = state.pathParameters['id'];
                if (id == null) return const ErrorScreen();

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
          path: 'admin-notifications', // Renamed to avoid confusion with main /notifications
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
                final generator = state.extra as Future<Uint8List> Function(PdfPageFormat)?;
                if (generator == null) return const ErrorScreen();

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
            return CreateExamScreen(
                initialCourseId: courseId,
                lessonId: lessonId,
                loadAllCourses: true);
          },
        ),
        GoRoute(
          path: 'exams/questions/:examId',
          builder: (context, state) {
            final examId = state.pathParameters['examId'];
            if (examId == null) return const ErrorScreen();

            final examTitle = state.uri.queryParameters['title'] ?? '';
            return ManageQuestionsScreen(
                examId: examId, examTitle: examTitle);
          },
        ),
      ],
    ),
  ];
}
