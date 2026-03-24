import 'dart:ui';
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
import '../../core/providers/navigation_provider.dart';
import '../packages/package_screen.dart';
import '../packages/all_packages_screen.dart';
import '../tips/all_tips_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/shimmer_loader.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/course_card.dart';
import 'widgets/home_drawer.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../categories/subjects_screen.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/string_utils.dart';
import '../../models/tip.dart';
import '../../models/bundle.dart';
import '../../widgets/vertical_tip_player.dart';
import '../../widgets/tip_preview_card.dart';
import '../../core/utils/safe_parser.dart';
import '../../models/banner_ad.dart';
import 'package:url_launcher/url_launcher.dart'; // Added
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _allCourses = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<CategoryModel> _categories = [];
  List<Tip> _tips = [];
  List<Bundle> _bundles = [];
  List<BannerAd> _banners = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasUnreadNotifications = false;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Set<String> _enrolledCourseIds = {};
  final Map<String, double> _enrollmentProgress = {}; // courseId -> progress %
  final Map<String, String> _enrollmentIds = {}; // courseId -> enrollmentId

  late PageController _bannerController;
  late PageController _bottomBannerController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentBannerPage = 0;
  int _currentBottomBannerPage = 0;

  List<Map<String, dynamic>> _normalizeMapList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return SafeParser.safeMapList(raw);
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Use a dynamic viewport fraction based on screen size (estimated at init)
    _bannerController = PageController(viewportFraction: 0.85);
    _bottomBannerController =
        PageController(viewportFraction: 1.0); // Full width for bottom banner
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
        _loadBanners(forceRefresh: forceRefresh),
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
    _bottomBannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;

      final bannerCount = _banners.isNotEmpty
          ? _banners.length
          : _allCourses.where((c) => c.isFeatured).length;

      if (bannerCount > 0) {
        // Top Banner
        if (_bannerController.hasClients) {
          final nextPage = (_currentBannerPage + 1) % bannerCount;
          _bannerController
              .animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          )
              .then((_) {
            if (mounted) setState(() => _currentBannerPage = nextPage);
          });
        }

        // Bottom Banner
        if (_bottomBannerController.hasClients && _banners.isNotEmpty) {
          final nextBottomPage =
              (_currentBottomBannerPage + 1) % _banners.length;
          _bottomBannerController
              .animateToPage(
            nextBottomPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          )
              .then((_) {
            if (mounted)
              setState(() => _currentBottomBannerPage = nextBottomPage);
          });
        }
      }
      _startBannerAutoPlay();
    });
  }

  Future<void> _loadTeachers({bool forceRefresh = false}) async {
    try {
      final teachers =
          await _databaseService.getAllTeachers(forceRefresh: forceRefresh);
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
      final categoriesData =
          await _databaseService.getCategories(forceRefresh: forceRefresh);
      final normalized = _normalizeMapList(categoriesData);
      if (mounted) {
        setState(() {
          _categories =
              normalized.map((e) => CategoryModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadTips({bool forceRefresh = false}) async {
    try {
      final tipsData =
          await _databaseService.getTips(forceRefresh: forceRefresh);
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
      final bundlesData =
          await _databaseService.getBundles(forceRefresh: forceRefresh);
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
          _allCourses =
              normalized.map((data) => Course.fromJson(data)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _loadBanners({bool forceRefresh = false}) async {
    try {
      final bannersData =
          await _databaseService.getBanners(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          final allBanners =
              bannersData.map((e) => BannerAd.fromJson(e)).toList();
          _banners = allBanners; // Keep the full list if needed elsewhere
        });
      }
    } catch (e) {
      debugPrint('Error loading banners: $e');
    }
  }

  Future<void> _loadEnrollmentProgress() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      final dynamic rawEnrollments =
          await _databaseService.getUserEnrollmentsWithProgress(userId);
      if (rawEnrollments is! Iterable) return;

      if (mounted) {
        setState(() {
          for (var item in rawEnrollments) {
            if (item is! Map) continue;
            final enrollment = SafeParser.safeMap(item);
            final courseId =
                (enrollment['course_id'] ?? enrollment['id'])?.toString();
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
                    onNotificationTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationsScreen())),
                  ),
                ),

                // Loading State (Shimmer)
                if (_isLoading && _allCourses.isEmpty)
                  SliverToBoxAdapter(child: _buildShimmerLoading()),

                if (!_isLoading || _allCourses.isNotEmpty) ...[
                  // 1. Unified Banner Carousel (Ads & Featured)
                  _buildUnifiedBannerCarousel(),

                  // 2. Search Bar
                  _buildSearchBar(),

                  // Continue Learning
                  SliverToBoxAdapter(child: _buildContinueLearning()),

                  // 4. Categories
                  if (_categories.isNotEmpty) _buildCategoriesSection(),

                  // 5. New Courses
                  if (_allCourses.isNotEmpty)
                    _buildNewCoursesSection(isWideScreen),

                  // 6. Most Watched
                  if (_allCourses.isNotEmpty)
                    _buildMostWatchedSection(isWideScreen),

                  // 7. Tips Section
                  _buildTipsSection(),

                  // 8. Featured Packages
                  _buildPackagesSection(isWideScreen),

                  // 8.5 Bottom Ad Banners
                  _buildBottomAdBanners(),

                  // 10. Top Teachers (Moved here per user request)
                  if (_filteredTeachers.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeaderBox(_t('top_teachers'), () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeachersListScreen(),
                              ),
                            );
                          }),
                          isWideScreen
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
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
                                  height: 220,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filteredTeachers.length,
                                    itemBuilder: (context, index) =>
                                        _buildTeacherItem(
                                            _filteredTeachers[index]),
                                  ),
                                ),
                        ],
                      ),
                    ),

                  // 10.5 Become a Teacher CTA (Shows for students/guests only)
                  _buildBecomeTeacherCTA(),

                  // 9. Recorded Courses
                  if (_allCourses.isNotEmpty)
                    _buildRecordedCoursesSection(isWideScreen),
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

  Widget _buildSectionHeaderBox(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
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
    );
  }

  Widget _buildTeacherItem(Map<String, dynamic> teacher) {
    final dynamic usersRaw = teacher['users'];
    final Map<String, dynamic>? userData =
        usersRaw is Map ? SafeParser.safeMap(usersRaw) : null;
    final name = StringUtils.cleanTeacherName(
        userData?['full_name'] ?? userData?['name'] ?? _t('teacher'));
    final avatarUrl = userData?['photo_url'] ?? userData?['avatar_url'];
    final specialization = userData?['specialization'] ?? '';

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
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
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getTextColor(context).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              ShimmerLoader.circular(height: 85, width: 85),
                          errorWidget: (context, url, e) => Container(
                            color: Colors.grey.shade900,
                            child: const Icon(Icons.person,
                                color: Colors.white24, size: 40),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.person,
                              color: Colors.white24, size: 40),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              // Specialization
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  specialization,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextColor(context).withOpacity(0.5),
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              // Label "مدرب"
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  _t('teacher_role'),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
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
            _t('continue_learning'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
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
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.1)),
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
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t('completed')} ${(_enrollmentProgress[lastCourse.id] ?? 0.0).toStringAsFixed(0)}%', // Replaced hardcoded string
                        style: TextStyle(
                          color:
                              AppColors.getTextColor(context, secondary: true),
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
                          backgroundColor:
                              AppColors.getGlassColor(context, opacity: 0.1),
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
                  icon: Icon(Icons.play_circle_fill,
                      color: AppColors.primaryPurple.withOpacity(0.9),
                      size: 40),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
                Provider.of<NavigationProvider>(context, listen: false)
                    .setIndex(1, focusSearch: true);
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        color:
                            AppColors.getTextColor(context, secondary: true)),
                    const SizedBox(width: 12),
                    Text(
                      _t('search_hint'),
                      style: TextStyle(
                          color:
                              AppColors.getTextColor(context, secondary: true),
                          fontSize: 16),
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

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderBox(_t('categories_title'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const SubjectsScreen(showBackButton: true)),
            );
          }),
          SizedBox(
            height: 220, // Enough height for 2 rows of ~95px cards plus padding
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 rows
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75, // height/width ratio: ~ 95 / 130
              ),
              itemCount: _categories
                  .where((c) => c.parentId == null || c.parentId!.isEmpty)
                  .length,
              itemBuilder: (context, index) {
                final parentCategories = _categories
                    .where((c) => c.parentId == null || c.parentId!.isEmpty)
                    .toList();
                final category = parentCategories[index];
                return CategoryCard(
                  category: category,
                  margin: EdgeInsets.zero, // Margin handled by Grid spacing
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExploreScreen(
                            initialFilter: category.id, showBackButton: true),
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

    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSectionHeaderBox(_t('new_courses'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExploreScreen(
                    initialFilter: 'newest', showBackButton: true),
              ),
            );
          }),
          SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: newCourses.take(10).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 280 : 220,
                    child: CourseCard(course: newCourses[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostWatchedSection(bool isWideScreen) {
    // Sort by student count descending
    final mostWatched = List<Course>.from(_allCourses);
    mostWatched.sort((a, b) => b.studentsCount.compareTo(a.studentsCount));

    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSectionHeaderBox(_t('most_watched'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExploreScreen(
                    initialFilter: 'popular', showBackButton: true),
              ),
            );
          }),
          SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: mostWatched.take(10).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 280 : 220,
                    child: CourseCard(course: mostWatched[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordedCoursesSection(bool isWideScreen) {
    var recordedCourses = List<Course>.from(_allCourses);
    // Shuffle to differentiate from New Courses
    recordedCourses.shuffle();
    if (recordedCourses.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSectionHeaderBox(_t('recorded_courses'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExploreScreen(
                    initialFilter: 'recorded', showBackButton: true),
              ),
            );
          }),
          SizedBox(
            height: isWideScreen ? 340 : 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: recordedCourses.take(10).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 280 : 220,
                    child: CourseCard(course: recordedCourses[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBecomeTeacherCTA() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfile = authService.userProfile;
    final String? role = userProfile?['role'];

    // Only show for guests (no profile) or students
    if (userProfile != null &&
        (role == 'teacher' || role == 'admin' || role == 'super_admin')) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Gradient & Pattern
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.deepPurple, // Deep Purple
                      AppColors.professionalBlue, // Professional Blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Decorative circles for premium feel
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.school_outlined,
                        color: Colors.white, size: 45),
                    const SizedBox(height: 16),
                    const Text(
                      'كن مدرباً وانضم إلينا في رحلة نمو دوراتي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'شارك خبرتك وساعد آلاف الطلاب على تحقيق أهدافهم وكن جزءاً من منصتنا التعليمية الكبرى',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RegisterScreen(initialRole: 'teacher'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: const Text(
                        'سجل الآن',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Cairo',
                        ),
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
  }

  Widget _buildTipsSection() {
    if (_tips.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderBox(_t('learning_tips_title'), () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const AllTipsScreen()));
          }),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _tips.length,
              itemBuilder: (context, index) {
                final tip = _tips[index];
                return TipPreviewCard(
                  tip: tip,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VerticalTipPlayer(tips: _tips, initialIndex: index),
                      ),
                    );
                  },
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
    if (_bundles.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderBox(_t('bundles_title'), () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AllPackagesScreen()));
          }),

          // Cards List
          SizedBox(
            height:
                290, // Adjusted height to accommodate image, text, divider, price and subscribe button
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _bundles.length,
              itemBuilder: (context, index) {
                final bundle = _bundles[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
                      width: 175, // Horizontal card width
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(11)),
                            child: AspectRatio(
                              aspectRatio: 1.4,
                              child: bundle.imageUrl != null &&
                                      bundle.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: bundle.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Container(color: Colors.black12),
                                      errorWidget: (context, url, err) =>
                                          Container(
                                              color: Colors.black12,
                                              child: const Icon(
                                                  Icons.broken_image)),
                                    )
                                  : Container(
                                      color: Colors.black12,
                                      child: const Icon(Icons.image)),
                            ),
                          ),

                          // 2. Content
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 10, 10, 10),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Title and Courses Count
                                  Column(
                                    children: [
                                      Text(
                                        bundle.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color:
                                              AppColors.getTextColor(context),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily:
                                              'Cairo', // Standard smooth font
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${bundle.courses.length} ${AppStrings.get('courses_count_bundle', locale) == 'courses_count_bundle' ? 'دورات' : AppStrings.get('courses_count_bundle', locale)}',
                                        style: TextStyle(
                                          color: AppColors.getTextColor(context,
                                              secondary: true),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Divider
                                  Divider(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.grey.shade200,
                                    height: 10,
                                    thickness: 1,
                                  ),

                                  // Missing price line added per user request
                                  if (bundle.price > 0)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (bundle.hasDiscount) ...[
                                          Text(
                                            bundle.getOriginalPrice(locale),
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              fontSize: 11,
                                              color: AppColors.getTextColor(
                                                      context,
                                                      secondary: true)
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          bundle.getFormattedPrice(locale),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color:
                                                AppColors.getTextColor(context),
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Subscribe Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.mutedPurpleBlue,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () {
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
                                      child: const Text(
                                        'اشترك',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

          // "See More" full-width button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AllPackagesScreen()));
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.primaryPurple.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  AppStrings.get('view_plans_button', locale) ==
                          'view_plans_button'
                      ? 'المزيد'
                      : 'المزيد',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildUnifiedBannerCarousel() {
    final topBanners = _banners.where((b) => b.location == 'top').toList();
    final bannerItems = topBanners.isNotEmpty
        ? topBanners
        : _allCourses
            .where((c) => c.isFeatured)
            .map((c) => BannerAd(
                  id: c.id,
                  title: c.getLocalizedTitle(
                      Provider.of<LocaleProvider>(context).locale),
                  subtitle: _t('featured_course_badge'),
                  imageUrl: c.imageUrl ?? '',
                  type: 'course',
                  targetId: c.id,
                  createdAt: c.createdAt ?? DateTime.now(),
                ))
            .toList();

    if (bannerItems.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _bannerController,
              onPageChanged: (index) {
                setState(() => _currentBannerPage = index);
              },
              itemCount: bannerItems.length,
              itemBuilder: (context, index) {
                final item = bannerItems[index];
                return _buildBannerItem(item);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bannerItems.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBannerPage == index
                      ? AppColors.primaryPurple
                      : AppColors.getTextColor(context).withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBottomAdBanners() {
    // Determine which banners to show at the bottom
    final bottomBanners =
        _banners.where((b) => b.location == 'bottom').toList();
    if (bottomBanners.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 180, // Responsive height for horizontal landscape banners
            child: PageView.builder(
              controller: _bottomBannerController,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentBottomBannerPage = index);
              },
              itemCount: bottomBanners.length,
              itemBuilder: (context, index) {
                final item = bottomBanners[index];
                final isLottie =
                    item.imageUrl.toLowerCase().endsWith('.json') ||
                        item.imageUrl.toLowerCase().endsWith('.lottie');

                // Determine button text
                String? buttonText = item.subtitle;
                if ((buttonText == null || buttonText.isEmpty) &&
                    item.type == 'external') {
                  buttonText = 'زيارة الرابط';
                }

                return InkWell(
                  onTap: () => _handleBannerTap(item),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Media Background
                      isLottie
                          ? Lottie.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.black12),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.black12),
                              errorWidget: (context, url, err) =>
                                  Container(color: Colors.black12),
                            ),

                      // Action Button Overlay
                      if (buttonText != null && buttonText.isNotEmpty)
                        Positioned(
                          bottom: 20,
                          left: 20, // Bottom-left by default
                          child: Directionality(
                            textDirection: TextDirection
                                .rtl, // Ensure Arabic text rendering is correct
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _handleBannerTap(item),
                              child: Text(
                                buttonText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bottomBanners.length,
              (index) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBottomBannerPage == index
                      ? AppColors.primaryPurple
                      : AppColors.getTextColor(context).withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBannerItem(BannerAd item) {
    return InkWell(
      onTap: () => _handleBannerTap(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10.0),
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
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white10),
                errorWidget: (context, url, e) =>
                    Container(color: Colors.grey.shade900),
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
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            item.subtitle!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                          if (item.type == 'external' ||
                              (item.subtitle != null &&
                                  item.subtitle!.isNotEmpty))
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 20),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBannerTap(BannerAd item) {
    if (item.type == 'course' && item.targetId != null) {
      final course = _allCourses.firstWhere((c) => c.id == item.targetId,
          orElse: () => Course(
                id: item.targetId!,
                title: item.title,
                instructorName: '',
                price: 0,
                rating: 0,
                studentsCount: 0,
                lessonsCount: 0,
                subject: '',
              ));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseDetailsScreen(course: course),
        ),
      );
    } else if (item.type == 'package' && item.targetId != null) {
      final bundle = _bundles.firstWhere((b) => b.id == item.targetId,
          orElse: () => _bundles.first);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PackageScreen(
              packageTitle: bundle.title,
              courses: bundle.courses,
              bundle: bundle),
        ),
      );
    } else if (item.type == 'external' && item.linkUrl != null) {
      final uri = Uri.tryParse(item.linkUrl!);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final authService = Provider.of<AuthService>(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Safety check to avoid division by zero if maxExtent equals minExtent
    final double range = maxExtent - minExtent;
    final double currentOpacity =
        range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final Color headerBackgroundColor = isDark
        ? AppColors.darkCardSurface.withOpacity(overlapsContent ? 0.96 : 0.9)
        : Colors.white.withOpacity(overlapsContent ? 0.98 : 0.92);

    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(
            Colors.transparent, headerBackgroundColor, currentOpacity),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: shrinkOffset > 20
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ]
            : [],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Right (Leading): Drawer Menu ---
            GestureDetector(
              onTap: onMenuTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu,
                    color: AppColors.getTextColor(context), size: 24),
              ),
            ),

            // --- Center: App Logo and Name ---
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: AppColors.primaryPurple,
                    size: 28,
                    shadows: [
                      Shadow(
                          color: AppColors.primaryPurple.withOpacity(0.5),
                          blurRadius: 10)
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t('app_name') == 'app_name'
                        ? 'دوراتي'
                        : t('app_name'), // Simple fallback
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                      fontFamily: 'Cairo', // Preferred custom font if available
                    ),
                  ),
                ],
              ),
            ),

            // --- Left (Trailing): Icons (Cart, Theme Toggle, Notifications, Login) ---
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!authService.isAuthenticated) ...[
                  // If not logged in, we can either hide or show icons limit. Let's show theme and login.
                  IconButton(
                    icon: Icon(
                        Provider.of<ThemeProvider>(context).isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.getTextColor(context),
                        size: 22),
                    onPressed: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .toggleTheme();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(t('login_title')),
                  ),
                ] else ...[
                  // Cart Icon
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CartScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context, opacity: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shopping_cart_outlined,
                          color: AppColors.getTextColor(context), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Theme Toggle
                  GestureDetector(
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .toggleTheme();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context, opacity: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          Provider.of<ThemeProvider>(context).isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: AppColors.getTextColor(context),
                          size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notifications
                  GestureDetector(
                    onTap: onNotificationTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context, opacity: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        children: [
                          Icon(Icons.notifications_outlined,
                              color: AppColors.getTextColor(context), size: 22),
                          if (hasUnreadNotifications)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.getSurfaceColor(context),
                                      width: 1.5),
                                ),
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
