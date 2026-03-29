import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/courses/course_details_screen.dart';
import '../../screens/courses/course_content_screen.dart';
import '../../screens/lesson/lesson_screen.dart';
import '../../screens/error_screen.dart';

List<RouteBase> getCourseRoutes(GlobalKey<NavigatorState> parentKey) {
  return [
    GoRoute(
      path: '/course/:id',
      parentNavigatorKey: parentKey, // Always use root nav for details
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) return const ErrorScreen();
        return CourseDetailsScreen(courseId: id);
      },
      routes: [
        GoRoute(
          path: 'content',
          builder: (context, state) {
            final courseId = state.pathParameters['id'];
            if (courseId == null || courseId.isEmpty) return const ErrorScreen();
            
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              return CourseContentScreen(
                course: extra['course'],
                lessonsData: extra['lessonsData'],
                chapters: extra['chapters'],
                isEnrolled: extra['isEnrolled'],
              );
            }
            
            return CourseDetailsScreen(
                courseId: courseId, startAtContent: true);
          },
        ),
        GoRoute(
          path: 'lesson/:lessonId',
          builder: (context, state) {
            final courseId = state.pathParameters['id'];
            final lessonId = state.pathParameters['lessonId'];
            
            if (courseId == null || courseId.isEmpty || lessonId == null || lessonId.isEmpty) {
              return const ErrorScreen();
            }

            return LessonScreen(courseId: courseId, lessonId: lessonId);
          },
        ),
      ],
    ),
  ];
}
