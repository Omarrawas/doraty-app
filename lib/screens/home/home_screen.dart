
import 'package:go_router/go_router.dart';
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
  Set<String> _accessibleCourseIds = {};
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
    Future.delayed(Duration(seconds: 4), () {
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
            duration: Duration(milliseconds: 800),
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
            duration: Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          )
              .then((_) {
            if (mounted) {
              setState(() => _currentBottomBannerPage = nextBottomPage);
            }
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
      final accessibleIds = await _databaseService.getAccessibleCourseIds();
      if (mounted) {
        setState(() {
          _enrolledCourseIds = enrolledIds;
          _accessibleCourseIds = accessibleIds.toSet();
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
              physics: AlwaysScrollableScrollPhysics(),
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
                            builder: (context) => NotificationsScreen())),
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
                            context.push('/teachers');
                          }),
                          isWideScreen
                              ? Padding(
                                  padding: EdgeInsets.symmetric(
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
                                    padding: EdgeInsets.symmetric(
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
                SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderBox(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        userData?['full_name'] ?? userData?['name'] ?? teacher['full_name'] ?? teacher['name'] ?? _t('teacher'));
    final avatarUrl = userData?['photo_url'] ?? userData?['avatar_url'] ?? teacher['photo_url'] ?? teacher['avatar_url'];
    final rawSubjects = userData?['subjects'] ?? teacher['subjects'] ?? teacher['specialization'];
    String specialization = '';
    if (rawSubjects is List) {
      specialization = rawSubjects.join('، ');
    } else if (rawSubjects is String) {
      specialization = rawSubjects;
    }

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
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                      ? (avatarUrl.toString().startsWith('data:')
                          ? Image.memory(
                              StringUtils.decodeBase64Image(avatarUrl.toString()),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey.shade900,
                                child: Icon(Icons.person,
                                    color: AppColors.getTextColor(context)
                                        .withOpacity(0.24),
                                    size: 40),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  ShimmerLoader.circular(height: 85, width: 85),
                              errorWidget: (context, url, e) => Container(
                                color: Colors.grey.shade900,
                                child: Icon(Icons.person,
                                    color: AppColors.getTextColor(context)
                                        .withOpacity(0.24),
                                    size: 40),
                              ),
                            ))
                      : Container(
                          color: Colors.grey.shade900,
                          child: Icon(Icons.person,
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.24),
                              size: 40),
                        ),
                ),
              ),
              SizedBox(height: 12),
              // Name
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
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
              SizedBox(height: 4),
              // Specialization
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
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
              SizedBox(height: 12),
              // Label "مدرب"
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
    if (enrolledCourses.isEmpty) return SizedBox.shrink();

    final lastCourse =
        enrolledCourses.first; // For now, just show the first enrolled

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
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
                SizedBox(width: 12),
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
                      SizedBox(height: 4),
                      Text(
                        '${_t('completed')} ${(_enrollmentProgress[lastCourse.id] ?? 0.0).toStringAsFixed(0)}%', // Replaced hardcoded string
                        style: TextStyle(
                          color:
                              AppColors.getTextColor(context, secondary: true),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
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
                SizedBox(width: 8),
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
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner Shimmer
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ShimmerLoader.rectangular(
            height: 180,
            shapeBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
        SizedBox(height: 20),
        // Section Title Shimmer
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ShimmerLoader.rectangular(height: 20, width: 150),
        ),
        SizedBox(height: 15),
        // Teacher Avatars Shimmer
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
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
        SizedBox(height: 30),
        // Courses Shimmer
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ShimmerLoader.rectangular(height: 24, width: 120),
        ),
        SizedBox(height: 16),
        ...List.generate(
            3,
            (index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: CourseCardShimmer(),
                )),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    SizedBox(width: 12),
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
            context.push('/topics');
          }),
          SizedBox(
            height: 120, // Height for a single row of cards
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
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
                  onTap: () {
                    context.push('/courses');
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
            context.push('/courses');
          }),
          SizedBox(
            height: isWideScreen ? 380 : 340,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: newCourses.take(10).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 320 : 280,
                    child: CourseCard(
                        course: newCourses[index],
                        heroTag: 'new_${newCourses[index].id}'),
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
            context.push('/courses');
          }),
          SizedBox(
            height: isWideScreen ? 380 : 340,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: mostWatched.take(10).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 320 : 280,
                    child: CourseCard(
                        course: mostWatched[index],
                        heroTag: 'watched_${mostWatched[index].id}'),
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
    
    if (recordedCourses.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    int rowsCount = recordedCourses.length > 5 ? 2 : 1;
    double cardHeight = isWideScreen ? 380 : 340;
    double cardWidth = isWideScreen ? 320 : 280;
    double containerHeight = (cardHeight * rowsCount) + ((rowsCount - 1) * 15.0);

    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSectionHeaderBox(_t('recorded_courses'), () {
            context.push('/courses');
          }),
          SizedBox(
            height: containerHeight,
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: rowsCount,
                childAspectRatio: cardHeight / cardWidth,
                mainAxisSpacing: 10,
                crossAxisSpacing: 15,
              ),
              itemCount: recordedCourses.length,
              itemBuilder: (context, index) {
                return CourseCard(
                  course: recordedCourses[index],
                  heroTag: 'recorded_${recordedCourses[index].id}',
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
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Gradient & Pattern
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
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
                    color: AppColors.getMutedTextColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.school_outlined,
                        color: AppColors.getTextColor(context), size: 45),
                    SizedBox(height: 16),
                    Text(
                      'كن مدرباً وانضم إلينا في رحلة نمو دوراتي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'شارك خبرتك وساعد آلاف الطلاب على تحقيق أهدافهم وكن جزءاً من منصتنا التعليمية الكبرى',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.70),
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.push('/register');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.deepPurple,
                        padding: EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: Text(
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
    if (_tips.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderBox(_t('learning_tips_title'), () {
            context.push('/tips');
          }),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 15),
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
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPackagesSection(bool isWideScreen) {
    if (_bundles.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeaderBox(_t('bundles_title'), () {
            context.push('/packages');
          }),

          // Cards List
          SizedBox(
            height:
                290, // Adjusted height to accommodate image, text, divider, price and subscribe button
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _bundles.length,
              itemBuilder: (context, index) {
                final bundle = _bundles[index];
                final bundleCourseIds =
                    bundle.courses.map((course) => course.id).toList();
                final bool hasBundleAccess = bundleCourseIds.isNotEmpty &&
                    bundleCourseIds.every(_accessibleCourseIds.contains);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
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
                                  offset: Offset(0, 4),
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
                                              child: Icon(
                                                  Icons.broken_image)),
                                    )
                                  : Container(
                                      color: Colors.black12,
                                      child: Icon(Icons.image)),
                            ),
                          ),

                          // 2. Content
                          Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                                      SizedBox(height: 4),
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
                                          SizedBox(width: 4),
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
                                        padding: EdgeInsets.symmetric(
                                            vertical: 6),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () {
                                        if (hasBundleAccess &&
                                            bundle.courses.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CourseDetailsScreen(
                                                course: bundle.courses.first,
                                              ),
                                            ),
                                          );
                                          return;
                                        }
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
                                      child: Text(
                                        hasBundleAccess ? 'أكمل' : 'اشترك',
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  context.push('/packages');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.primaryPurple.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: 12),
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
          SizedBox(height: 10),
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

    if (bannerItems.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

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
          SizedBox(height: 12),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bannerItems.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBannerPage == index
                      ? AppColors.primaryPurple
                      : AppColors.getTextColor(context).withOpacity(0.3),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBottomAdBanners() {
    // Determine which banners to show at the bottom
    final bottomBanners =
        _banners.where((b) => b.location == 'bottom').toList();
    if (bottomBanners.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _handleBannerTap(item),
                              child: Text(
                                buttonText,
                                style: TextStyle(
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
          SizedBox(height: 10),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bottomBanners.length,
              (index) => Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBottomBannerPage == index
                      ? AppColors.primaryPurple
                      : AppColors.getTextColor(context).withOpacity(0.3),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBannerItem(BannerAd item) {
    return InkWell(
      onTap: () => _handleBannerTap(item),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
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
                placeholder: (context, url) => Container(color: AppColors.getTextColor(context).withOpacity(0.10)),
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
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            item.subtitle!,
                            style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: AppColors.getTextColor(context),
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
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.getTextColor(context).withOpacity(0.24),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Icon(Icons.arrow_forward_rounded,
                                  color: AppColors.getTextColor(context), size: 20),
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
      height: maxExtent,
      decoration: BoxDecoration(
        color: Color.lerp(
            Colors.transparent, headerBackgroundColor, currentOpacity),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: shrinkOffset > 20
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5))
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
                padding: EdgeInsets.all(8),
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
                  SizedBox(width: 8),
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
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      context.push('/login');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(t('login_title')),
                  ),
                ] else ...[
                  // Cart Icon
                  GestureDetector(
                    onTap: () {
                      context.push('/cart');
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context, opacity: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shopping_cart_outlined,
                          color: AppColors.getTextColor(context), size: 22),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Theme Toggle
                  GestureDetector(
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .toggleTheme();
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
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
                  SizedBox(width: 12),
                  // Notifications
                  GestureDetector(
                    onTap: onNotificationTap,
                    child: Container(
                      padding: EdgeInsets.all(8),
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
