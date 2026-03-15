import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/course.dart';
import 'course_details_screen.dart';

class CourseLoaderScreen extends StatefulWidget {
  final String courseId;

  const CourseLoaderScreen({super.key, required this.courseId});

  @override
  State<CourseLoaderScreen> createState() => _CourseLoaderScreenState();
}

class _CourseLoaderScreenState extends State<CourseLoaderScreen> {
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      final data = await _db.getCourseById(widget.courseId);
      if (data != null) {
        if (!mounted) return;
        
        // Map data to Course object
        final course = Course(
          id: data['id'],
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          instructorId: data['instructor_id'],
          instructorName: data['instructor_name'] ?? data['users']?['full_name'] ?? '',
          instructorPhoto: data['instructor_photo'] ?? data['users']?['avatar_url'] ?? '',
          imageUrl: data['image_url'] ?? data['thumbnail'] ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0,
          rating: (data['rating'] as num?)?.toDouble() ?? 0,
          studentsCount: data['students_count'] ?? 0,
          lessonsCount: data['lessons_count'] ?? 0,
          durationHours: data['duration_hours']?.toString() ?? data['duration'],
          categories: List<String>.from(data['categories_names'] ?? []),
          categoryIds: List<String>.from(data['category_ids'] ?? []),
          subject: data['subject'] ?? '',
          curriculum: [],
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(course: course),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('عذراً، لم يتم العثور على الدورة')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading course: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
