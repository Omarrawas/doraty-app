import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
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
import '../../core/services/auth_service.dart';

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
  Map<String, dynamic> _teacherStats = {};

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
    // Use a dynamic viewport fraction based on screen size (estimated at init)
    _bannerController = PageController(viewportFraction: 0.85);
    _startBannerAutoPlay();
    _refreshData();
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (forceRefresh) {
      if (mounted) setState(() => _isLoading = true);
    }

    await Future.wait([
      _loadCategories(forceRefresh: forceRefresh),
      _loadFeaturedCourses(forceRefresh: forceRefresh),
      _loadEnrolledCourses(), // Enrollments usually small and fast, can be kept simple
      _loadFeaturedBanner(forceRefresh: forceRefresh),
       _loadTeachers(forceRefresh: forceRefresh),
      _checkUnreadNotifications(),
      _loadTeacherStats(forceRefresh: forceRefresh),
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
    // Profile is managed by provider, no need for manual local state updates here
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

  Future<void> _loadTeacherStats({bool forceRefresh = false}) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userRole = authService.userProfile?['role'];
    if (userRole != 'teacher' && userRole != 'admin' && userRole != 'super_admin') {
      return;
    }

    try {
      final userId = authService.userProfile?['id'];
      if (userId != null) {
        final stats = await _databaseService.getTeacherStatistics(userId,
            forceRefresh: forceRefresh);
        if (mounted) {
          setState(() {
            _teacherStats = stats;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;

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
                  // Teacher Performance Summary (Contextual)
                  SliverToBoxAdapter(child: _buildTeacherQuickStats()),

                  // Continue Learning
                  SliverToBoxAdapter(child: _buildContinueLearning()),

                  // Banner Carousel
                  SliverToBoxAdapter(child: _buildBannerCarousel()),

                  // Teachers Section
                  if (_filteredTeachers.isNotEmpty) ...[
                    _buildSectionHeader(_t('top_teachers'), () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TeachersListScreen(),
                        ),
                      );
                    }),
                    SliverToBoxAdapter(
                      child: isWideScreen
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 20,
                                children: _filteredTeachers
                                    .take(isWideScreen ? 12 : 6)
                                    .map((t) => _buildTeacherItem(t))
                                    .toList(),
                              ),
                            )
                          : SizedBox(
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

                  // Featured Courses Section Header
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        _t('featured_courses'),
                        style: TextStyle(
                          fontSize: isWideScreen ? 26 : 22,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  _featuredCourses.isEmpty
                      ? SliverToBoxAdapter(
                          child: ProfessionalEmptyState(
                            title: _t('no_courses_found'),
                            message: _t('no_featured_courses_message'),
                            icon: Icons.auto_awesome_motion_rounded,
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: isWideScreen
                              ? SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildCourseCard(_featuredCourses[index]),
                                    childCount: _featuredCourses.length,
                                  ),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                                )
                              : SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 500,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _featuredCourses.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 16),
                                          child: _buildCourseCard(_featuredCourses[index]),
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

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                _t('explore_more'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: AppColors.primaryPurple.withOpacity(0.9),
                ),
              ),
            ),
          ],
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
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final userName =
            auth.userProfile?['full_name'] ?? auth.userProfile?['name'];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo & Greeting (Left Side)
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName != null
                                ? '${_t('welcome_with_name')} $userName 👋'
                                : '${_t('welcome')} 👋',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _t('ready_to_learn'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Notifications (Right Side)
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
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final List<Map<String, String>> dynamicCategories = [
      {'key': 'all', 'name': _t('all')},
      ..._categoryModels
          .map((e) => {'key': e.id, 'name': e.getLocalizedName(locale)})
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;

    if (isLargeScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: dynamicCategories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            return _buildCategoryChipItem(cat, isSelected);
          }).toList(),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: dynamicCategories.length,
        itemBuilder: (context, index) {
          final cat = dynamicCategories[index];
          final isSelected = _selectedCategory == cat['key']; // Compare with key
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildCategoryChipItem(cat, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChipItem(Map<String, String> cat, bool isSelected) {
    return ChoiceChip(
      label: Text(
        cat['name']!, // Display localized name
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.getTextColor(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      backgroundColor: AppColors.getGlassColor(context, opacity: 0.2),
      selectedColor: AppColors.primaryPurple.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : AppColors.getGlassColor(context, opacity: 0.3),
        ),
      ),
      showCheckmark: false,
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
            style: TextStyle(color: AppColors.getTextColor(context)),
            cursorColor: AppColors.primaryPurple,
            decoration: InputDecoration(
              hintText: _t('search_course_hint'),
              hintStyle: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.getTextColor(context, secondary: true),
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

  Widget _buildTeacherQuickStats() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userRole = authService.userProfile?['role'];
    if (userRole != 'teacher' &&
        userRole != 'admin' &&
        userRole != 'super_admin') {
      return const SizedBox.shrink();
    }

    if (_teacherStats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('performance_summary'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to dashboard if needed
                },
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard(
                _t('total_revenue'),
                '${_teacherStats['total_revenue'] ?? 0}',
                Icons.account_balance_wallet_outlined,
                Colors.greenAccent,
              ),
              const SizedBox(width: 15),
              _buildStatCard(
                _t('active_students'),
                '${_teacherStats['total_users'] ?? 0}',
                Icons.people_outline,
                Colors.blueAccent,
              ),
              const SizedBox(width: 15),
              _buildStatCard(
                _t('courses_count'),
                '${_teacherStats['total_courses'] ?? 0}',
                Icons.book_outlined,
                Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getGlassColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
