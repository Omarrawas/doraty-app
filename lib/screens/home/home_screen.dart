import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../courses/course_details_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../teacher/teacher_profile_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _featuredCourses = [];
  List<Course> _allCourses = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  String? _userBranch;

  String _searchQuery = '';
  Set<String> _enrolledCourseIds = {};

  @override
  void initState() {
    super.initState();
    _loadUserBranch();
    _loadFeaturedCourses();
    _loadEnrolledCourses();
    _loadEnrolledCourses();
    _loadTeachers();
    _checkUnreadNotifications();
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await _databaseService.getAllTeachers();
      if (mounted) {
        setState(() {
          _allTeachers = teachers;
          _filterCourses(); // Re-run filter to include teachers
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
    }
  }

  Future<void> _loadUserBranch() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        return;
      }

      final userData = await SupabaseService.instance.client
          .from('users')
          .select('branch')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userBranch = userData?['branch'] as String?;
          // Filter courses after loading branch
          _filterCourses();
        });
      }
    } catch (e) {
      debugPrint('Error loading user branch: $e');
    }
  }

  Future<void> _loadEnrolledCourses() async {
    try {
      final enrolledIds = await _databaseService.getEnrolledCourseIds();
      if (mounted) {
        setState(() {
          _enrolledCourseIds = enrolledIds;
        });
      }
    } catch (e) {
      debugPrint('Error loading enrolled courses: $e');
    }
  }

  Future<void> _loadFeaturedCourses() async {
    try {
      final coursesData = await _databaseService.getCourses();

      if (mounted) {
        setState(() {
          _allCourses = coursesData
              .map((data) => Course(
                    id: data['id'],
                    title: data['title'] ?? '',
                    description: data['description'] ?? '',
                    instructorId: data['instructor_id'],
                    instructorName: data['instructor_name'] ?? '',
                    instructorPhoto: data['instructor_photo'] ?? '',
                    imageUrl: data['image_url'] ?? data['thumbnail'] ?? '',
                    price: (data['price'] as num?)?.toDouble() ?? 0,
                    rating: (data['rating'] as num?)?.toDouble() ?? 0,
                    studentsCount: data['students_count'] ?? 0,
                    lessonsCount: data['lessons_count'] ?? 0,
                    durationHours:
                        data['duration_hours']?.toString() ?? data['duration'],
                    category: data['category'] ?? '',
                    subject: data['subject'] ?? '',
                    curriculum: [],
                    isEnrolled: false,
                  ))
              .toList();
          _filterCourses();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterCourses() {
    List<Course> filteredCourses = _allCourses;
    List<Map<String, dynamic>> filteredTeachers = _allTeachers;

    // Filter by user's branch first (Only affects courses)
    if (_userBranch != null && _userBranch!.isNotEmpty) {
      filteredCourses = filteredCourses.where((course) {
        return (course.category ?? '').toLowerCase() ==
            _userBranch!.toLowerCase();
      }).toList();
    }

    // Then apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredCourses = filteredCourses.where((course) {
        return course.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (course.description ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            course.subject.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      filteredTeachers = filteredTeachers.where((teacher) {
        final userData = teacher['users'] as Map<String, dynamic>?;
        final name = userData?['name'] as String? ?? '';
        return name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    _featuredCourses = filteredCourses;
    _filteredTeachers = filteredTeachers;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user branch and courses when returning from settings
    _loadUserBranch();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterCourses();
    });
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final notifications = await _databaseService.getNotifications();
      final unreadCount =
          notifications.where((n) => n['is_read'] == false).length;
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = unreadCount > 0;
        });
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _loadUserBranch(),
                      _loadFeaturedCourses(),
                      _loadEnrolledCourses(),
                      _loadTeachers(),
                      _checkUnreadNotifications(),
                    ]);
                  },
                  color: AppColors.primaryPurple,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSearchBar(),
                        ),

                        // Teachers Section
                        if (_filteredTeachers.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'المدرسين المتاحين',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100, // Fixed height for teachers list
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: _filteredTeachers.length,
                              itemBuilder: (context, index) {
                                final teacher = _filteredTeachers[index];
                                final userData =
                                    teacher['users'] as Map<String, dynamic>?;
                                final name = userData?['name'] ?? 'مدرس';
                                final avatarUrl = userData?['photo_url'];

                                return Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TeacherProfileScreen(
                                            teacherId: teacher['user_id'] ??
                                                '', // Assuming user_id is the key in user_roles
                                            teacherName: name,
                                            teacherPhoto: avatarUrl,
                                            bio: userData?['bio'],
                                            specialization: userData?[
                                                    'branch'] ??
                                                'مدرس', // Map branch to specialization
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            image: DecorationImage(
                                              image: avatarUrl != null &&
                                                      avatarUrl
                                                          .toString()
                                                          .isNotEmpty
                                                  ? CachedNetworkImageProvider(
                                                          avatarUrl)
                                                      as ImageProvider
                                                  : NetworkImage(
                                                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 254, 254),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Featured Courses Section
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'دورات مميزة',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Featured Courses
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              )
                            : _featuredCourses.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(40),
                                      child: Text(
                                        'لا توجد دورات متاحة',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 320,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      itemCount: _featuredCourses.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(left: 16),
                                          child: _buildCourseCard(
                                              _featuredCourses[index]),
                                        );
                                      },
                                    ),
                                  ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Notifications Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (_hasUnreadNotifications)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Title
          const Row(
            children: [
              Text(
                'مرحباً بك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: TextField(
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color.fromARGB(255, 15, 12, 12)),
            decoration: InputDecoration(
              hintText: 'ابحث عن دورة...',
              hintStyle: TextStyle(
                color: const Color.fromARGB(255, 2, 1, 1).withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailsScreen(course: course),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: course.imageUrl ?? '',
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        height: 140,
                        color: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Icons.image,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course Title
                        Text(
                          course.title,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Instructor
                        Text(
                          course.instructorName,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Rating and Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              course.formattedPrice,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  course.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Enroll Button
                        _buildEnrollButton(course),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrollButton(Course course) {
    final isEnrolled = _enrolledCourseIds.contains(course.id);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailsScreen(course: course),
            ),
          ).then((_) {
            // Reload enrolled courses when returning from details
            _loadEnrolledCourses();
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnrolled
              ? Colors.green.withOpacity(0.8)
              : AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEnrolled ? Icons.check_circle : Icons.visibility_outlined,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isEnrolled ? 'مضافة' : 'اطلاع',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
