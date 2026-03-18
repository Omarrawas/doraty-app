import 'package:flutter/material.dart';
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
import '../../core/services/sync_service.dart';
import '../../widgets/course_card.dart';

import '../../widgets/empty_state.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';

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

  Set<String> _enrolledCourseIds = {};
  final Map<String, double> _enrollmentProgress = {}; // courseId -> progress %
  final Map<String, String> _enrollmentIds = {}; // courseId -> enrollmentId

  late PageController _bannerController;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    // Use a dynamic viewport fraction based on screen size (estimated at init)
    _bannerController = PageController(viewportFraction: 0.85);
    _startBannerAutoPlay();
    _refreshData();
    
    // Listen to sync completion
    SyncService().addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted && !SyncService().isSyncing) {
      debugPrint('🔄 Sync completed, refreshing UI...');
      _refreshData(forceRefresh: false); // Reload from now-updated cache
    }
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        if (mounted) setState(() => _isLoading = true);
      }

      await Future.wait([
        _loadFeaturedCourses(forceRefresh: forceRefresh),
        _loadEnrolledCourses(), // Enrollments usually small and fast, can be kept simple
        _loadFeaturedBanner(forceRefresh: forceRefresh),
        _loadTeachers(forceRefresh: forceRefresh),
        _checkUnreadNotifications(),
        _loadTeacherStats(forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      debugPrint('Error refreshing home data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    SyncService().removeListener(_onSyncUpdate);
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
          _filteredTeachers = _allTeachers; // Show all on home
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
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
          
          final seenIds = <String>{};
          _featuredCourses = _allCourses.where((c) => seenIds.add(c.id)).take(10).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
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
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      // Access the profile from AuthService if available, otherwise fetch manually
      final authService = Provider.of<AuthService>(context, listen: false);
      String? userRole = authService.userProfile?['role'];

      // If role is still null, we might need a small delay or fetch it once
      if (userRole == null) {
        final profile = await _databaseService.getUserProfile(userId);
        userRole = profile['role'];
      }

      if (userRole == null) return;

      Map<String, dynamic> stats = {};

      if (userRole == 'admin' || userRole == 'super_admin') {
        // Admin sees global stats
        stats = await _databaseService.getSystemStatistics(forceRefresh: forceRefresh);
      } else if (userRole == 'teacher') {
        // Teacher sees only their stats
        stats = await _databaseService.getTeacherStatistics(userId, forceRefresh: forceRefresh);
      } else {
        // Regular student doesn't see this section
        if (mounted) setState(() => _teacherStats = {});
        return;
      }

      if (mounted) {
        setState(() {
          _teacherStats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats in HomeScreen: $e');
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



                // Loading State (Shimmer)
                if (_isLoading)
                  SliverToBoxAdapter(child: _buildShimmerLoading()),

                if (!_isLoading) ...[
                  // Teacher Performance Summary (Contextual)
                  SliverToBoxAdapter(child: _buildTeacherQuickStats()),

                  // Accreditation Section
                  SliverToBoxAdapter(child: _buildAccreditationSection()),

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
                                    (context, index) => CourseCard(
                                      course: _featuredCourses[index],
                                      heroTag: 'home_course_image_${_featuredCourses[index].id}',
                                    ),
                                    childCount: _featuredCourses.length,
                                  ),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.8,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                                )
                              : SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 420,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _featuredCourses.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsetsDirectional.only(start: 16),
                                          child: CourseCard(
                                            course: _featuredCourses[index],
                                            heroTag: 'home_course_image_${_featuredCourses[index].id}',
                                          ),
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
        userData?['full_name'] ?? userData?['name'] ?? _t('teacher'));
    final avatarUrl = userData?['photo_url'] ?? userData?['avatar_url'];

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
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
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  color: Colors.white10,
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => ShimmerLoader.circular(height: 65, width: 65),
                          errorWidget: (context, url, error) => _buildAvatarPlaceholder(name),
                        )
                      : _buildAvatarPlaceholder(name),
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



  Widget _buildAccreditationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTrustBadge(Icons.verified_user_outlined, _t('accredited_by')),
          _buildTrustBadge(Icons.security_outlined, "Verified"),
          _buildTrustBadge(Icons.payments_outlined, "Secure Pay"),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
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
              padding: EdgeInsetsDirectional.only(start: 16),
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

  Widget _buildTeacherQuickStats() {
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

  Widget _buildAvatarPlaceholder(String name) {
    return Image.network(
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff',
      fit: BoxFit.cover,
    );
  }
}
