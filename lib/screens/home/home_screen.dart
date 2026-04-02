
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../teacher/teacher_profile_screen.dart';
import '../../models/category_model.dart';
import '../explore/widgets/category_card.dart';
import '../../core/providers/navigation_provider.dart';
import '../../widgets/shimmer_loader.dart';
import '../../core/services/app_init_state.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/course_card.dart';
import 'widgets/home_drawer.dart';
import '../packages/package_screen.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/string_utils.dart';
import '../../models/tip.dart';
import '../../models/bundle.dart';
import '../../widgets/vertical_tip_player.dart';
import '../../widgets/tip_preview_card.dart';
import '../../widgets/live_course_card.dart';
import '../../core/utils/safe_parser.dart';
import '../../models/banner_ad.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _allCourses = []; // Keep as fallback/dummy if needed
  List<Course> _featuredCourses = [];
  List<Course> _newCourses = [];
  List<Course> _popularCourses = [];
  List<Course> _recordedCourses = [];
  List<Course> _enrolledCourses = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<CategoryModel> _categories = [];
  List<Tip> _tips = [];
  List<Bundle> _bundles = [];
  List<BannerAd> _banners = [];
  List<Course> _liveCourses = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasUnreadNotifications = false;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

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
    
    // 1. Wait for services to be ready if they aren't yet
    if (!AppInitState.servicesReady) {
      debugPrint('⏳ HomeScreen: Services not ready, waiting...');
      int attempts = 0;
      while (!AppInitState.servicesReady && attempts < 50) {
        // 5s max wait
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (mounted) setState(() => _isRefreshing = true);

    try {
      debugPrint('🔄 HomeScreen: Refreshing data (force: $forceRefresh)...');

      // Load essential UI data first to show content ASAP
      // We don't await Future.wait at once to allow individual setState calls to render UI partially
      final essentialTasks = [
        _loadBanners(forceRefresh: forceRefresh),
        _loadCategories(forceRefresh: forceRefresh),
      ];

      await Future.wait(essentialTasks);

      // Once essential data is ready (banners/categories), stop showing global loading if they have data
      if (mounted && (_banners.isNotEmpty || _categories.isNotEmpty)) {
        setState(() => _isLoading = false);
      }

      // Load main content in background/parallel
      final contentTasks = [
        _loadNewCourses(forceRefresh: forceRefresh),
        _loadFeaturedCourses(forceRefresh: forceRefresh),
        _loadPopularCourses(forceRefresh: forceRefresh),
        _loadRecordedCourses(forceRefresh: forceRefresh),
        _loadBundles(forceRefresh: forceRefresh),
        _loadTips(forceRefresh: forceRefresh),
        _loadTeachers(forceRefresh: forceRefresh),
      ];

      // Load user-specific data
      final userTasks = [
        _loadEnrolledCourses(),
        _checkUnreadNotifications(),
      ];

      // Run everything else
      await Future.wait([...contentTasks, ...userTasks]);

      // Load live/in-person courses (separate, non-blocking)
      _loadLiveCourses(forceRefresh: forceRefresh);

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
          : _featuredCourses.length;

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
          _accessibleCourseIds = accessibleIds.toSet();
        });
      }

      // Batch fetch the actual course objects for enrolled IDs (Lite versions)
      if (enrolledIds.isNotEmpty) {
        final List<Course> finalEnrolledCourses = [];
        final List<String> missingIds = [];

        for (final id in enrolledIds) {
          try {
            // Priority 1: Check if already in memory (fastest)
            final existing = [_newCourses, _featuredCourses, _popularCourses]
                .expand((x) => x)
                .firstWhere((c) => c.id == id);
            finalEnrolledCourses.add(existing);
          } catch (_) {
            missingIds.add(id);
          }
        }

        // Priority 2: Batch fetch all missing IDs from DB/Cache (1 request vs N)
        if (missingIds.isNotEmpty) {
          try {
            final missingCoursesData = await _databaseService.getLiteCourses(
              ids: missingIds,
              limit: missingIds.length,
            );
            finalEnrolledCourses.addAll(
              missingCoursesData.map((data) => Course.fromJson(data)).toList()
            );
          } catch (e) {
            debugPrint('Error batch fetching missing enrolled courses: $e');
          }
        }
        
        if (mounted) {
          setState(() {
            _enrolledCourses = finalEnrolledCourses;
          });
        }
      }

      // Load progress data for enrolled courses
      await _loadEnrollmentProgress();
    } catch (e) {
      debugPrint('Error loading enrolled courses: $e');
    }
  }

  Future<void> _loadLiveCourses({bool forceRefresh = false}) async {
    try {
      final response = await _databaseService.supabaseClient
          .from('courses')
          .select()
          .inFilter('delivery_mode', ['live', 'in_person'])
          .eq('is_published', true)
          .limit(10);
      final normalized = _normalizeMapList(response);
      if (mounted) {
        setState(() {
          _liveCourses = normalized.map((e) => Course.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading live courses: $e');
    }
  }

  Future<void> _loadNewCourses({bool forceRefresh = false}) async {
    try {
      final coursesData = await _databaseService.getLiteCourses(
        limit: 10,
        forceRefresh: forceRefresh,
      );
      final normalized = _normalizeMapList(coursesData);
      if (mounted) {
        setState(() {
          _newCourses = normalized.map((data) => Course.fromJson(data)).toList();
          if (_allCourses.isEmpty) _allCourses = _newCourses;
        });
      }
    } catch (e) {
      debugPrint('Error loading new courses: $e');
    }
  }

  Future<void> _loadFeaturedCourses({bool forceRefresh = false}) async {
    try {
      final coursesData = await _databaseService.getLiteCourses(
        limit: 8,
        forceRefresh: forceRefresh,
      );
      final normalized = _normalizeMapList(coursesData);
      if (mounted) {
        setState(() {
          _featuredCourses = normalized.map((data) => Course.fromJson(data)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading featured courses: $e');
    }
  }

  Future<void> _loadPopularCourses({bool forceRefresh = false}) async {
    try {
      final coursesData = await _databaseService.getLiteCourses(
        limit: 10,
        forceRefresh: forceRefresh,
        orderBy: 'students_count',
        ascending: false,
      );
      final normalized = _normalizeMapList(coursesData);
      if (mounted) {
        setState(() {
          _popularCourses =
              normalized.map((data) => Course.fromJson(data)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading popular courses: $e');
    }
  }

  Future<void> _loadRecordedCourses({bool forceRefresh = false}) async {
    try {
      // Fetch recorded courses sorted by the latest update (e.g. when a lesson is added)
      final response = await _databaseService.supabaseClient
          .from('courses')
          .select(DatabaseService.liteCourseColumns)
          .eq('delivery_mode', 'recorded')
          .eq('is_published', true)
          .order('updated_at', ascending: false)
          .limit(20);
      
      final normalized = _normalizeMapList(response);
      if (mounted) {
        setState(() {
          _recordedCourses = normalized.map((e) => Course.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recorded courses: $e');
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
                    isAuthenticated: authService.isAuthenticated,
                    isLoadingProfile: authService.isLoadingProfile,
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onNotificationTap: () => context.push('/notifications'),
                  ),
                ),

                // Loading State (Shimmer)
                if (_isLoading && _allCourses.isEmpty)
                  SliverToBoxAdapter(child: _buildShimmerLoading()),

                if (!_isLoading || _allCourses.isNotEmpty) ...[
                  // 1. Unified Banner Carousel (Ads & Featured)
                  _buildUnifiedBannerCarousel(),

                  // Guest Call-to-Action Banner
                  if (!authService.isAuthenticated)
                    _buildGuestBanner(isWideScreen),


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

                  // 7.5 Live & In-person Courses
                  if (_liveCourses.isNotEmpty)
                    _buildLiveCoursesSection(),

                  // 8. Featured Packages
                  _buildPackagesSection(isWideScreen),

                  // 8.5 Bottom Ad Banners
                  _buildBottomAdBanners(),

                  // 10. Top Teachers + Become a Trainer — unified card
                  _buildTeachersAndTrainerSection(isWideScreen),

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


  Widget _buildContinueLearning() {
    // Show only if there are enrolled courses
    if (_enrolledCourses.isEmpty) return SizedBox.shrink();

    final enrolledCourses = _enrolledCourses;

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
                    final identifier = lastCourse.slug.isNotEmpty ? lastCourse.slug : lastCourse.id;
                    context.push('/course/$identifier');
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

  // ─── Live / In-Person Courses Section ───────────────────────────
  SliverToBoxAdapter _buildLiveCoursesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                      Text(
                        'دورات مباشرة وحضورية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.push('/explore?filter=live'),
                    child: Text(
                      'عرض الكل',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryPurple.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Horizontal scroll
            SizedBox(
              height: 270,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _liveCourses.length,
                itemBuilder: (context, index) =>
                    LiveCourseCard(course: _liveCourses[index]),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
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

  Widget _buildGuestBanner(bool isWideScreen) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6E48AA).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative elements inside the banner
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'انضم إلى مجتمع دوراتي!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'سجل الآن كطالب لتتعلم مهارات جديدة، أو كمدرب لتنشر دوراتك.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () => context.push('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF6E48AA),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('إنشاء حساب', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => context.push('/login'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('تسجيل دخول'),
                          ),
                        ),
                      ],
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

  Widget _buildSearchBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
                context.go('/courses');
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppColors.getGlassColor(context, opacity: 0.1)
                      : AppColors.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isDark
                          ? AppColors.getGlassColor(context, opacity: 0.2)
                          : AppColors.getBorderColor(context)),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
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
            height: 180, // Increased height for larger, rounded cards + padding
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
                    context.go('/courses?categoryId=${category.id}');
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
    if (_newCourses.isEmpty) return SliverToBoxAdapter(child: SizedBox.shrink());

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
              itemCount: _newCourses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 320 : 280,
                    child: CourseCard(
                        course: _newCourses[index],
                        heroTag: 'new_${_newCourses[index].id}'),
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
    if (_popularCourses.isEmpty) return SliverToBoxAdapter(child: SizedBox.shrink());

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
              itemCount: _popularCourses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: isWideScreen ? 320 : 280,
                    child: CourseCard(
                        course: _popularCourses[index],
                        heroTag: 'watched_${_popularCourses[index].id}'),
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
    if (_recordedCourses.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    int rowsCount = _recordedCourses.length > 5 ? 2 : 1;
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
              itemCount: _recordedCourses.length,
              itemBuilder: (context, index) {
                return CourseCard(
                  course: _recordedCourses[index],
                  heroTag: 'recorded_${_recordedCourses[index].id}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Unified: Top Teachers + Become a Trainer ───────────────────────────
  Widget _buildTeachersAndTrainerSection(bool isWideScreen) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfile = authService.userProfile;
    final String? role = userProfile?['role'];
    final bool showCTA = userProfile == null ||
        (role != 'teacher' && role != 'admin' && role != 'super_admin');
    final bool hasTeachers = _filteredTeachers.isNotEmpty;

    if (!hasTeachers && !showCTA) return SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.deepPurple,
                  AppColors.professionalBlue,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Decorative background circles
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Teachers Section ──
                    if (hasTeachers) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t('top_teachers'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/teachers'),
                              child: Text(
                                _t('explore_more'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      isWideScreen
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: _filteredTeachers
                                    .take(12)
                                    .map((t) => _buildTeacherItemLight(t))
                                    .toList(),
                              ),
                            )
                          : SizedBox(
                              height: 220,
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: _filteredTeachers.length,
                                itemBuilder: (context, index) =>
                                    _buildTeacherItemLight(_filteredTeachers[index]),
                              ),
                            ),
                    ],

                    // ── Divider ──
                    if (hasTeachers && showCTA)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Divider(
                          color: Colors.white.withOpacity(0.15),
                          thickness: 1,
                        ),
                      ),

                    // ── Become a Trainer CTA ──
                    if (showCTA)
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, hasTeachers ? 0 : 24, 24, 28),
                        child: Column(
                          children: [
                            Icon(Icons.school_outlined,
                                color: Colors.white, size: 42),
                            SizedBox(height: 14),
                            Text(
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
                            SizedBox(height: 10),
                            Text(
                              'شارك خبرتك وساعد آلاف الطلاب على تحقيق أهدافهم وكن جزءاً من منصتنا التعليمية الكبرى',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                                height: 1.6,
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => context.push('/register'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.deepPurple,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 36, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                                shadowColor: Colors.black38,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Light-themed teacher card for use inside the gradient container
  Widget _buildTeacherItemLight(Map<String, dynamic> teacher) {
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
      padding: const EdgeInsetsDirectional.only(end: 12),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 140,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
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
                              errorBuilder: (_, __, ___) => _defaultAvatarLight(),
                            )
                          : CachedNetworkImage(
                              imageUrl: avatarUrl.toString(),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _defaultAvatarLight(),
                              errorWidget: (_, __, ___) => _defaultAvatarLight(),
                            ))
                      : _defaultAvatarLight(),
                ),
              ),
              SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (specialization.isNotEmpty) ...[
                SizedBox(height: 3),
                Text(
                  specialization,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  _t('teacher_role'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
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

  Widget _defaultAvatarLight() {
    return Container(
      color: Colors.white12,
      child: Icon(Icons.person, color: Colors.white54, size: 40),
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
                                          final identifier = bundle.courses.first.slug.isNotEmpty ? bundle.courses.first.slug : bundle.courses.first.id;
                                          context.push('/course/$identifier');
                                          return;
                                        }
                                        final identifier = bundle.slug.isNotEmpty ? bundle.slug : bundle.id;
                                        context.push('/package/$identifier');
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
        : _featuredCourses
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
      // Look in all our optimized lists
      Course? course;
      try {
        course = [_newCourses, _featuredCourses, _popularCourses, _enrolledCourses]
            .expand((x) => x)
            .firstWhere((c) => c.id == item.targetId);
      } catch (_) {
        // Not found in memory, navigate by ID (Screen will fetch data)
      }
      
      final identifier = (course != null && course.slug.isNotEmpty) 
          ? course.slug 
          : item.targetId!;
      context.push('/course/$identifier');
    } else if (item.type == 'package' && item.targetId != null) {
      final bundle = _bundles.firstWhere((b) => b.id == item.targetId,
          orElse: () => _bundles.first);
      final identifier = bundle.slug.isNotEmpty ? bundle.slug : bundle.id;
      context.push('/package/$identifier');
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

  final bool isAuthenticated;
  final bool isLoadingProfile;

  _HomeHeaderDelegate({
    required this.userName,
    required this.hasUnreadNotifications,
    required this.t,
    required this.onMenuTap,
    required this.onNotificationTap,
    required this.isAuthenticated,
    required this.isLoadingProfile,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Safety check to avoid division by zero if maxExtent equals minExtent
    final double range = maxExtent - minExtent;
    final double currentOpacity =
        range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final Color headerBackgroundColor = isDark
        ? AppColors.darkCardSurface.withOpacity(overlapsContent ? 0.98 : 0.92)
        : Colors.white.withOpacity(overlapsContent ? 1.0 : 0.96);

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
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.07),
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
                if (!isAuthenticated) ...[
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
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.07),
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
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.07),
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
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.07),
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
        oldDelegate.isAuthenticated != isAuthenticated ||
        oldDelegate.isLoadingProfile != isLoadingProfile ||
        oldDelegate.hasUnreadNotifications != hasUnreadNotifications;
  }
}
