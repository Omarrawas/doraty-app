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
import '../teacher/teachers_list_screen.dart'; // Added import
import '../notifications/notifications_screen.dart';
import '../../widgets/shimmer_loader.dart';
import '../../models/category_model.dart';
import '../../widgets/empty_state.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _featuredCourses = [];
  List<Course> _allCourses = [];
  List<Course> _featuredCoursesForBanner = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isLoading = true;
  bool _hasUnreadNotifications = false;
  String? _userName;
  String? _userPhoto;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  String _searchQuery = '';
  String _selectedCategory = 'all';
  Set<String> _enrolledCourseIds = {};
  final Map<String, double> _enrollmentProgress = {}; // courseId -> progress %
  final Map<String, String> _enrollmentIds = {}; // courseId -> enrollmentId
  List<CategoryModel> _categoryModels = [];

  late PageController _bannerController;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(viewportFraction: 0.85);
    _startBannerAutoPlay();
    _refreshData();
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (forceRefresh) {
      if (mounted) setState(() => _isLoading = true);
    }

    await Future.wait([
      _loadUserData(forceRefresh: forceRefresh),
      _loadCategories(forceRefresh: forceRefresh),
      _loadFeaturedCourses(forceRefresh: forceRefresh),
      _loadEnrolledCourses(), // Enrollments usually small and fast, can be kept simple
      _loadFeaturedBanner(forceRefresh: forceRefresh),
      _loadTeachers(forceRefresh: forceRefresh),
      _checkUnreadNotifications(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _allCourses.isNotEmpty) {
        final nextPage =
            (_currentBannerPage + 1) % (_allCourses.take(3).length);
        _bannerController
            .animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        )
            .then((_) {
          if (mounted) {
            setState(() => _currentBannerPage = nextPage);
            _startBannerAutoPlay();
          }
        });
      }
    });
  }

  Future<void> _loadTeachers({bool forceRefresh = false}) async {
    try {
      final teachers =
          await _databaseService.getAllTeachers(forceRefresh: forceRefresh);
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

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    try {
      final categoriesData =
          await _databaseService.getCategories(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _categoryModels =
              categoriesData.map((e) => CategoryModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      final userData = await _databaseService.getUserById(userId,
          forceRefresh: forceRefresh);

      if (mounted && userData != null) {
        setState(() {
          _userName = userData['full_name'] ?? userData['name'] ?? '';
          _userPhoto = userData['avatar_url'] ?? userData['photo_url'];
          _filterCourses();
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
      // Load progress data for enrolled courses
      await _loadEnrollmentProgress();
    } catch (e) {
      debugPrint('Error loading enrolled courses: $e');
    }
  }

  Future<void> _loadFeaturedCourses({bool forceRefresh = false}) async {
    try {
      // getCourses internally caches to OfflineCacheService
      final coursesData =
          await _databaseService.getCourses(forceRefresh: forceRefresh);
      
      if (mounted) {
        setState(() {
          _allCourses = coursesData
              .map((data) => Course.fromJson(data))
              .toList();
          _filterCourses();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  void _filterCourses() {
    List<Course> filteredCourses = _allCourses;
    List<Map<String, dynamic>> filteredTeachers = _allTeachers;

    // Filter by category chip
    if (_selectedCategory != 'all') {
      // Updated condition
      filteredCourses = filteredCourses.where((course) {
        // Match by subject or any category name
        final locale =
            Provider.of<LocaleProvider>(context, listen: false).locale;
        final localizedSubject = course.getLocalizedSubject(locale);

        return localizedSubject.toLowerCase() ==
                _selectedCategory.toLowerCase() ||
            course.subject.toLowerCase() == _selectedCategory.toLowerCase() ||
            course.categories.any(
                (cat) => cat.toLowerCase() == _selectedCategory.toLowerCase());
      }).toList();

      // For teachers, we just show all teachers if a category is selected OR
      // we could implement teacher categories later. For now, keep all teachers
      // or filter if needed. Let's keep all for better UX unless search is active.
      filteredTeachers = _allTeachers;
    } else {
      // Reset teachers to all if category is 'all'
      filteredTeachers = _allTeachers;
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

    // Ensure unique courses by ID
    final seenIds = <String>{};
    _featuredCourses = filteredCourses.where((c) => seenIds.add(c.id)).toList();
    _filteredTeachers = filteredTeachers;
  }

  Future<void> _loadFeaturedBanner({bool forceRefresh = false}) async {
    try {
      final featured =
          await _databaseService.getFeaturedCourses(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _featuredCoursesForBanner = featured
              .map((data) => Course.fromJson(data))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading featured banner: $e');
    }
  }

  Future<void> _loadEnrollmentProgress() async {
    try {
      final userId = _databaseService.supabaseClient.auth.currentUser?.id;
      if (userId == null) return;

      final enrollments =
          await _databaseService.getUserEnrollmentsWithProgress(userId);

      if (mounted) {
        setState(() {
          for (var enrollment in enrollments) {
            final courseId = enrollment['course_id'];
            _enrollmentProgress[courseId] =
                (enrollment['progress_percentage'] ?? 0.0).toDouble();
            _enrollmentIds[courseId] = enrollment['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading enrollment progress: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user courses when returning from settings
    _loadUserData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterCourses();
    });
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final unreadCount = await _databaseService.getUnreadNotificationsCount();
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
      body: RefreshIndicator(
        onRefresh: () => _refreshData(forceRefresh: true),
        color: AppColors.primaryPurple,
        backgroundColor: AppColors.getGlassColor(context),
        child: DynamicGradientBackground(
          child: SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Premium Header
                SliverToBoxAdapter(child: _buildHeader()),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: _buildSearchBar(),
                  ),
                ),

                // Category Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _buildCategoryChips(),
                  ),
                ),

                // Loading State (Shimmer)
                if (_isLoading)
                  SliverToBoxAdapter(child: _buildShimmerLoading()),

                if (!_isLoading) ...[
                  // Continue Learning
                  SliverToBoxAdapter(child: _buildContinueLearning()),

                  // Banner Carousel
                  SliverToBoxAdapter(child: _buildBannerCarousel()),

                  // Teachers Section
                  if (_filteredTeachers.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t('top_teachers'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TeachersListScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                _t('explore_more'), // Using 'explore_more' or 'all' depending on preference
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: AppColors.primaryPurple.withOpacity(
                                      0.9), // Lighter purple or accent
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 110,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: _filteredTeachers.length,
                          itemBuilder: (context, index) =>
                              _buildTeacherItem(_filteredTeachers[index]),
                        ),
                      ),
                    ),
                  ],

                  // Featured Courses Section
                  SliverPadding(
                    // Changed to SliverPadding to allow Text widget
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        _t('featured_courses'), // Replaced hardcoded string
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  _featuredCourses.isEmpty
                      ? SliverToBoxAdapter(
                          child: ProfessionalEmptyState(
                            title: _t(
                                'no_courses_found'), // Replaced hardcoded string
                            message: _t(
                                'no_featured_courses_message'), // Replaced hardcoded string
                            icon: Icons.auto_awesome_motion_rounded,
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(bottom: 30),
                          sliver: SliverToBoxAdapter(
                            child: SizedBox(
                              height: 500,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _featuredCourses.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: _buildCourseCard(
                                        _featuredCourses[index]),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherItem(Map<String, dynamic> teacher) {
    final userData = teacher['users'] as Map<String, dynamic>?;
    final name = StringUtils.cleanTeacherName(
        userData?['full_name_en'] != null &&
                Provider.of<LocaleProvider>(context).locale == 'en'
            ? userData!['full_name_en']
            : (userData?['full_name'] ?? userData?['name'] ?? _t('teacher')));
    final avatarUrl = userData?['photo_url'] ?? userData?['avatar_url'];

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherProfileScreen(
                teacherId: teacher['user_id'] ?? '',
                teacherName: name,
                teacherPhoto: avatarUrl,
                bio: userData?['bio'],
              ),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Colors.purpleAccent,
                    Colors.blueAccent,
                    Colors.cyanAccent
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  image: DecorationImage(
                    image: avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                        : NetworkImage(
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Notifications
          Row(
            children: [
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
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 24),
                      if (_hasUnreadNotifications)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Title & Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _userName != null
                      ? '${_t('welcome_with_name')}, $_userName 👋'
                      : '${_t('welcome')} 👋', // Replaced hardcoded string
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _t('ready_to_learn'), // Replaced hardcoded string
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // User Avatar
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: _userPhoto != null
                  ? CachedNetworkImage(
                      imageUrl: _userPhoto!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.white10),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.white),
                    )
                  : const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final List<Map<String, String>> dynamicCategories = [
      {'key': 'all', 'name': _t('all')},
      ..._categoryModels
          .map((e) => {'key': e.id, 'name': e.getLocalizedName(locale)})
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: dynamicCategories.length,
        itemBuilder: (context, index) {
          final cat = dynamicCategories[index];
          final isSelected =
              _selectedCategory == cat['key']; // Compare with key
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                cat['name']!, // Display localized name
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      isSelected ? FontWeight.normal : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat['key']!; // Set internal key
                    _filterCourses();
                  });
                }
              },
              backgroundColor: Colors.white.withOpacity(0.2),
              selectedColor: AppColors.primaryPurple.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.white30,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
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
            textAlign: Provider.of<LocaleProvider>(context).locale == 'ar'
                ? TextAlign.right
                : TextAlign.left,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _t('search_course_hint'),
              hintStyle: const TextStyle(
                color: Colors.white,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white,
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

  Widget _buildContinueLearning() {
    // Show only if there are enrolled courses
    final enrolledCourses =
        _allCourses.where((c) => _enrolledCourseIds.contains(c.id)).toList();
    if (enrolledCourses.isEmpty) return const SizedBox.shrink();

    final lastCourse =
        enrolledCourses.first; // For now, just show the first enrolled

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('continue_learning'), // Replaced hardcoded string
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryPurple.withOpacity(0.4),
                  Colors.blue.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: lastCourse.imageUrl ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastCourse.getLocalizedTitle(
                            Provider.of<LocaleProvider>(context).locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t('completed')} ${(_enrollmentProgress[lastCourse.id] ?? 0.0).toStringAsFixed(0)}%', // Replaced hardcoded string
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              (_enrollmentProgress[lastCourse.id] ?? 0.0) / 100,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CourseDetailsScreen(course: lastCourse),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    // Use admin-selected featured courses, or fallback to top 3 courses
    final bannerCourses = _featuredCoursesForBanner.isNotEmpty
        ? _featuredCoursesForBanner
        : _allCourses.take(3).toList();
    if (bannerCourses.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() => _currentBannerPage = index);
            },
            itemCount: bannerCourses.length,
            itemBuilder: (context, index) {
              final course = bannerCourses[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsScreen(
                        course: course,
                        heroTag: 'banner_course_image_${course.id}',
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'banner_course_image_${course.id}',
                          child: CachedNetworkImage(
                            imageUrl: course.imageUrl ?? '',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.white10),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _t('featured_course_badge'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.normal),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                course.getLocalizedTitle(
                                    Provider.of<LocaleProvider>(context)
                                        .locale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannerCourses.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerPage == index
                    ? AppColors.primaryPurple
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner Shimmer
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ShimmerLoader.rectangular(
            height: 180,
            shapeBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Section Title Shimmer
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ShimmerLoader.rectangular(height: 20, width: 150),
        ),
        const SizedBox(height: 15),
        // Teacher Avatars Shimmer
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  ShimmerLoader.circular(height: 65, width: 65),
                  SizedBox(height: 8),
                  ShimmerLoader.rectangular(height: 12, width: 50),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Courses Shimmer
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ShimmerLoader.rectangular(height: 24, width: 120),
        ),
        const SizedBox(height: 16),
        ...List.generate(
            3,
            (index) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: CourseCardShimmer(),
                )),
      ],
    );
  }

  Widget _buildCourseBadge(Course course) {
    // Show "Most Popular" badge if course has 50+ students
    if (course.studentsCount >= 50) {
      return Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orangeAccent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                _t('most_popular'), // Replaced hardcoded string
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCourseCard(Course course) {
    final locale = Provider.of<LocaleProvider>(context).locale;
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
                    builder: (context) => CourseDetailsScreen(
                      course: course,
                      heroTag: 'home_course_image_${course.id}',
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Course Title
                            Text(
                              course.getLocalizedTitle(locale),
                              textAlign: locale == 'ar'
                                  ? TextAlign.right
                                  : TextAlign.left,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Instructor
                            Text(
                              course.getLocalizedInstructorName(locale),
                              textAlign: locale == 'ar'
                                  ? TextAlign.right
                                  : TextAlign.left,
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
                                  course.getFormattedPrice(locale),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      course.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
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
                          ],
                        ),
                      ),

                      // Course Image (Now at the bottom as a square)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: Hero(
                              tag: 'home_course_image_${course.id}',
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: course.imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.white.withOpacity(0.2),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildEnrollButton(course),
                      ),
                    ],
                  ),
                  _buildCourseBadge(course),
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
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
