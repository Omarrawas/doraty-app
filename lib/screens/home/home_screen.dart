import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../courses/course_details_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../teacher/teacher_profile_screen.dart';
import '../teacher/teachers_list_screen.dart'; 
import '../../models/category_model.dart';
import '../explore/widgets/category_card.dart';
import '../explore/explore_screen.dart';
import '../categories/category_courses_screen.dart';
import '../search/search_screen.dart';
import '../packages/package_screen.dart';
import '../packages/all_packages_screen.dart';
import '../tips/all_tips_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/shimmer_loader.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/course_card.dart';
import 'widgets/home_drawer.dart';
import '../auth/login_screen.dart';
import '../categories/subjects_screen.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/string_utils.dart';
import '../../models/tip.dart';
import '../../models/bundle.dart';
import '../../widgets/vertical_tip_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _allCourses = [];
  List<Course> _featuredCoursesForBanner = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<CategoryModel> _categories = [];
  List<Tip> _tips = [];
  List<Bundle> _bundles = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasUnreadNotifications = false;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Set<String> _enrolledCourseIds = {};
  final Map<String, double> _enrollmentProgress = {}; // courseId -> progress %
  final Map<String, String> _enrollmentIds = {}; // courseId -> enrollmentId

  late PageController _bannerController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentBannerPage = 0;

  List<Map<String, dynamic>> _normalizeMapList(dynamic raw) {
    if (raw is! Iterable) return <Map<String, dynamic>>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }

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
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    try {
      debugPrint('🔄 HomeScreen: Refreshing data (force: $forceRefresh)...');
      
      // Load all data points in parallel with individual error catching
      await Future.wait([
        _loadTeachers(forceRefresh: forceRefresh),
        _loadCategories(forceRefresh: forceRefresh),
        _loadCourses(forceRefresh: forceRefresh),
        _loadEnrolledCourses(),
        _loadFeaturedBanner(forceRefresh: forceRefresh),
        _loadTips(forceRefresh: forceRefresh),
        _loadBundles(forceRefresh: forceRefresh),
        _checkUnreadNotifications(),
      ]);
      
      debugPrint('✅ HomeScreen: Data refresh complete');
    } catch (e) {
      debugPrint('🚨 HomeScreen: Critical error in _refreshData: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
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
      final teachers = await _databaseService.getAllTeachers(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(teachers);
      if (mounted) {
        setState(() {
          _allTeachers = normalized;
          _filteredTeachers = _allTeachers;
        });
      }
    } catch (e) {
      debugPrint('❌ HomeScreen: Error loading teachers: $e');
    }
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    try {
      final categoriesData = await _databaseService.getCategories(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(categoriesData);
      if (mounted) {
        setState(() {
          _categories = normalized.map((e) => CategoryModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadTips({bool forceRefresh = false}) async {
    try {
      final tipsData = await _databaseService.getTips(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(tipsData);
      if (mounted) {
        setState(() {
          _tips = normalized.map((e) => Tip.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading tips: $e');
    }
  }

  Future<void> _loadBundles({bool forceRefresh = false}) async {
    try {
      final bundlesData = await _databaseService.getBundles(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(bundlesData);
      if (mounted) {
        setState(() {
          _bundles = normalized.map((e) => Bundle.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading bundles: $e');
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

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    try {
      final coursesData =
          await _databaseService.getCourses(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(coursesData);
      
      if (mounted) {
        setState(() {
          _allCourses = normalized
              .map((data) => Course.fromJson(data))
              .toList();
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
      final normalized = _normalizeMapList(featured);
      if (mounted) {
        setState(() {
          _featuredCoursesForBanner = normalized
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
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      final dynamic rawEnrollments = await _databaseService.getUserEnrollmentsWithProgress(userId);
      if (rawEnrollments is! Iterable) return;

      if (mounted) {
        setState(() {
          for (var item in rawEnrollments) {
            if (item is! Map) continue;
            final enrollment = Map<String, dynamic>.from(item);
            final courseId = (enrollment['course_id'] ?? enrollment['id'])?.toString();
            if (courseId != null) {
              final progressRaw = enrollment['progress_percentage'];
              final progress = progressRaw is num
                  ? progressRaw.toDouble()
                  : double.tryParse(progressRaw?.toString() ?? '0') ?? 0.0;
              _enrollmentProgress[courseId] = progress;
              _enrollmentIds[courseId] = enrollment['id']?.toString() ?? '';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ HomeScreen: Error loading enrollment progress: $e');
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;
    final authService = Provider.of<AuthService>(context);

    // If we're on the white screen, it might be because the scaffold's body crashed.
    // We add an ErrorWidget around any potentially risky areas.
    return Scaffold(
      key: _scaffoldKey,
      drawer: HomeDrawer(categories: _categories),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(forceRefresh: true),
        color: AppColors.primaryPurple,
        backgroundColor: AppColors.getGlassColor(context),
        child: DynamicGradientBackground(
          child: SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Premium Sticky Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _HomeHeaderDelegate(
                    userName: (authService.userProfile?['full_name'] ??
                            authService.userProfile?['name'])
                        ?.toString(),
                    hasUnreadNotifications: _hasUnreadNotifications,
                    t: _t,
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                  ),
                ),

                // Loading State (Shimmer)
                if (_isLoading && _allCourses.isEmpty)
                  SliverToBoxAdapter(child: _buildShimmerLoading()),

                if (!_isLoading || _allCourses.isNotEmpty) ...[
                  // 1. Top Banner (Carousel)
                  SliverToBoxAdapter(child: _buildBannerCarousel()),

                  // 2. Search Bar
                  _buildSearchBar(),

                  // 3. Ad Banner
                  _buildAdBanner(),

                  // Continue Learning
                  SliverToBoxAdapter(child: _buildContinueLearning()),

                  // 4. Categories
                  if (_categories.isNotEmpty) _buildCategoriesSection(),

                  // 5. New Courses
                  if (_allCourses.isNotEmpty) _buildNewCoursesSection(isWideScreen),

                  // 6. Most Watched
                  if (_allCourses.isNotEmpty) _buildMostWatchedSection(isWideScreen),

                  // 7. Tips Section
                  _buildTipsSection(),

                  // 8. Featured Packages
                  _buildPackagesSection(isWideScreen),

                  // 9. Recorded Courses
                  if (_allCourses.isNotEmpty) _buildRecordedCoursesSection(isWideScreen),

                  // 10. Top Teachers
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
                ],
                // Add padding at bottom
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
    final dynamic usersRaw = teacher['users'];
    final Map<String, dynamic>? userData =
        usersRaw is Map ? Map<String, dynamic>.from(usersRaw) : null;
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

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: AppColors.primaryPurple.withOpacity(0.2),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
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

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Hero(
          tag: 'search_bar',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const SearchScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(
                      _t('search_hint'),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.purpleAccent.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('ad_banner_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('ad_banner_subtitle'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllPackagesScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 0,
                    ),
                    child: Text(
                      _t('view_plans_button'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.stars_rounded, color: Colors.white.withOpacity(0.5), size: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(_t('categories_title'), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubjectsScreen(showBackButton: true)),
            );
          }),
          SizedBox(
            height: 120,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return CategoryCard(
                  category: category,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExploreScreen(initialFilter: category.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewCoursesSection(bool isWideScreen) {
    // Sort by created_at descending
    final newCourses = List<Course>.from(_allCourses);
    newCourses.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    
    return Column(
      children: [
        _buildSectionHeader(_t('new_courses'), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploreScreen(initialFilter: 'newest'),
            ),
          );
        }),
        SliverToBoxAdapter(
          child: SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: newCourses.take(6).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: CourseCard(course: newCourses[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMostWatchedSection(bool isWideScreen) {
    // Sort by enrollment count if available, placeholder sort for now
    final mostWatched = List<Course>.from(_allCourses);
    mostWatched.shuffle(); // Placeholder logic
    
    return Column(
      children: [
        _buildSectionHeader(_t('most_watched'), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploreScreen(initialFilter: 'popular'),
            ),
          );
        }),
        SliverToBoxAdapter(
          child: SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: mostWatched.take(6).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: CourseCard(course: mostWatched[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordedCoursesSection(bool isWideScreen) {
    final recordedCourses = _allCourses.where((c) => c.status == 'recorded').toList();
    if (recordedCourses.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _buildSectionHeader(_t('recorded_courses'), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploreScreen(initialFilter: 'recorded'),
            ),
          );
        }),
        SliverToBoxAdapter(
          child: SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: recordedCourses.take(6).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: CourseCard(course: recordedCourses[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    if (_tips.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(_t('learning_tips_title'), () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AllTipsScreen()));
          }),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _tips.length,
              itemBuilder: (context, index) {
                final tip = _tips[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VerticalTipPlayer(tips: _tips, initialIndex: index),
                        ),
                      );
                    },
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(tip.thumbnailUrl ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.play_circle_fill, color: Colors.white.withOpacity(0.8), size: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPackagesSection(bool isWideScreen) {
    if (_bundles.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(_t('bundles_title'), () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AllPackagesScreen()));
          }),
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _bundles.length,
              itemBuilder: (context, index) {
                final bundle = _bundles[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PackageScreen(
                            packageTitle: bundle.title,
                            courses: bundle.courses,
                            bundle: bundle,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 300,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryPurple.withOpacity(0.8),
                            Colors.blueAccent.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bundle.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bundle.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${bundle.price} ${_t('currency')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String? userName;
  final bool hasUnreadNotifications;
  final String Function(String) t;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;

  _HomeHeaderDelegate({
    required this.userName,
    required this.hasUnreadNotifications,
    required this.t,
    required this.onMenuTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final authService = Provider.of<AuthService>(context);
    
    // Safety check to avoid division by zero if maxExtent equals minExtent
    final double range = maxExtent - minExtent;
    final double currentOpacity = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context).withOpacity(currentOpacity),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: shrinkOffset > 20 
          ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
          : [],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu & Greeting
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onMenuTap,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.menu, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authService.isAuthenticated 
                            ? '${t('hello')}, ${userName ?? t('user')}'
                            : t('home'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Theme Toggle & Notifications & Login
                Row(
                  children: [
                    if (!authService.isAuthenticated)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(t('login_title')),
                      )
                    else ...[
                      // Theme Toggle (Quick Access)
                      IconButton(
                        icon: Icon(
                          Provider.of<ThemeProvider>(context).isDarkMode 
                              ? Icons.light_mode_rounded 
                              : Icons.dark_mode_rounded, 
                          color: Colors.white, 
                          size: 20
                        ),
                        onPressed: () {
                          Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        },
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onNotificationTap,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                              if (hasUnreadNotifications)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 90.0;

  @override
  double get minExtent => 90.0;

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return oldDelegate.userName != userName || 
           oldDelegate.hasUnreadNotifications != hasUnreadNotifications;
  }
}
