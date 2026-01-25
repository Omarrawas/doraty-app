import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/database_service.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/string_utils.dart';
import '../../core/theme/app_colors.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? teacherPhoto;
  final String? bio;

  const TeacherProfileScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.teacherPhoto,
    this.bio,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _teacherCourses = [];
  bool _isLoading = true;

  // Teacher data loaded from database
  String? _teacherBio;
  String? _teacherPhoto;
  String _teacherName = '';

  @override
  void initState() {
    super.initState();
    _teacherName = StringUtils.cleanTeacherName(widget.teacherName);
    _teacherPhoto = widget.teacherPhoto;
    _teacherBio = widget.bio;
    _loadTeacherData();
    _loadTeacherCourses();
  }

  Future<void> _loadTeacherData({bool forceRefresh = false}) async {
    try {
      // Get complete teacher data from database
      final userData = await _databaseService.getUserById(widget.teacherId,
          forceRefresh: forceRefresh);
      if (mounted && userData != null) {
        setState(() {
          _teacherName = StringUtils.cleanTeacherName(
              userData['full_name'] ?? userData['name'] ?? widget.teacherName);
          _teacherPhoto = userData['photo_url'] ??
              userData['avatar_url'] ??
              widget.teacherPhoto;
          _teacherBio = userData['bio'];
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher data: $e');
      // Keep using widget data if loading fails
    }
  }

  Future<void> _loadTeacherCourses({bool forceRefresh = false}) async {
    try {
      final coursesData =
          await _databaseService.getCoursesByTeacherId(widget.teacherId);
      if (mounted) {
        setState(() {
          _teacherCourses =
              coursesData.map((data) => Course.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadTeacherData(forceRefresh: true),
      _loadTeacherCourses(forceRefresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppColors.primaryPurple,
        backgroundColor: Colors.white,
        child: DynamicGradientBackground(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 80, bottom: 20),
                  child: Column(
                    children: [
                      // Teacher Info
                      _buildTeacherInfo(),
                      const SizedBox(height: 30),

                      // Courses
                      _buildCoursesList(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTeacherInfo() {
    return Column(
      children: [
        // Avatar
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: _teacherPhoto != null && _teacherPhoto!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _teacherPhoto!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.network(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          _teacherName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 8),

        // Bio
        if (_teacherBio != null && _teacherBio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _teacherBio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoursesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.library_books, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'دورات المدرس (${_teacherCourses.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_teacherCourses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'لا توجد دورات متاحة حالياً',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _teacherCourses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CourseCard(course: _teacherCourses[index]),
              );
            },
          ),
      ],
    );
  }
}
