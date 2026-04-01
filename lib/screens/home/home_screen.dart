
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../teacher/teacher_profile_screen.dart';
import '../../models/category_model.dart';
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
import '../../core/utils/safe_parser.dart';
import '../../models/banner_ad.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';

// ─── Windows 2000 Design System ─────────────────────────────────────────────

class Win2K {
  // Classic Win2K color palette
  static const Color silver = Color(0xFFD4D0C8);
  static const Color silverLight = Color(0xFFECE9D8);
  static const Color silverDark = Color(0xFF808080);
  static const Color white = Color(0xFFFFFFFF);
  static const Color shadow = Color(0xFF808080);
  static const Color darkShadow = Color(0xFF404040);
  static const Color titleBarStart = Color(0xFF0A246A);
  static const Color titleBarEnd = Color(0xFF3A6EA5);
  static const Color titleBarText = Color(0xFFFFFFFF);
  static const Color windowBg = Color(0xFFECE9D8);
  static const Color desktopTeal = Color(0xFF3A6EA5);
  static const Color accent = Color(0xFF000080);
  static const Color accentBlue = Color(0xFF0000FF);
  static const Color linkBlue = Color(0xFF0000FF);
  static const Color selectedBg = Color(0xFF316AC5);
  static const Color selectedText = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF000000);
  static const Color textGray = Color(0xFF555555);
  static const Color buttonFace = Color(0xFFD4D0C8);
  static const Color menuBg = Color(0xFFFFFFFF);
  static const Color tooltipBg = Color(0xFFFFFFE1);
  static const Color progressBar = Color(0xFF00009C);
  static const Color greenSuccess = Color(0xFF008000);

  // Raised (button) border
  static BoxDecoration raised({Color bg = Win2K.buttonFace}) => BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: Win2K.white, width: 1.5),
          left: BorderSide(color: Win2K.white, width: 1.5),
          bottom: BorderSide(color: Win2K.darkShadow, width: 1.5),
          right: BorderSide(color: Win2K.darkShadow, width: 1.5),
        ),
      );

  // Sunken (input/inset) border
  static BoxDecoration sunken({Color bg = Win2K.white}) => BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: Win2K.darkShadow, width: 1.5),
          left: BorderSide(color: Win2K.darkShadow, width: 1.5),
          bottom: BorderSide(color: Win2K.white, width: 1.5),
          right: BorderSide(color: Win2K.white, width: 1.5),
        ),
      );

  // Group box border (like a dialog section)
  static BoxDecoration groupBox() => BoxDecoration(
        color: Win2K.silverLight,
        border: Border(
          top: BorderSide(color: Win2K.shadow, width: 1),
          left: BorderSide(color: Win2K.shadow, width: 1),
          bottom: BorderSide(color: Win2K.white, width: 1),
          right: BorderSide(color: Win2K.white, width: 1),
        ),
      );

  // Classic title bar gradient
  static BoxDecoration titleBar() => const BoxDecoration(
        gradient: LinearGradient(
          colors: [titleBarStart, titleBarEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      );

  static TextStyle get sysFont => const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: textDark,
        letterSpacing: 0,
      );

  static TextStyle get titleFont => const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: titleBarText,
        letterSpacing: 0,
      );
}

// ─── Win2K Raised Button Widget ─────────────────────────────────────────────

class Win2KButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const Win2KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  State<Win2KButton> createState() => _Win2KButtonState();
}

class _Win2KButtonState extends State<Win2KButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: _pressed
            ? Win2K.sunken(bg: widget.color ?? Win2K.buttonFace)
            : Win2K.raised(bg: widget.color ?? Win2K.buttonFace),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon,
                  size: 14, color: widget.textColor ?? Win2K.textDark),
              const SizedBox(width: 4),
            ],
            Text(
              widget.label,
              style: Win2K.sysFont.copyWith(
                  color: widget.textColor ?? Win2K.textDark,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Win2K Section Group Box ─────────────────────────────────────────────────

class Win2KGroupBox extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;

  const Win2KGroupBox({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
    this.seeAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar row
          Container(
            decoration: Win2K.titleBar(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.folder_open,
                    size: 14, color: Win2K.titleBarText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title, style: Win2K.titleFont),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: Win2K.raised(),
                      child: Text(
                        seeAllLabel ?? 'See All',
                        style: Win2K.sysFont,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: Win2K.groupBox(),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Main Home Screen ────────────────────────────────────────────────────────

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
  final Map<String, double> _enrollmentProgress = {};
  final Map<String, String> _enrollmentIds = {};

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
    _bannerController = PageController(viewportFraction: 1.0);
    _bottomBannerController = PageController(viewportFraction: 1.0);
    _startBannerAutoPlay();
    _refreshData();
    SyncService().addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted && !SyncService().isSyncing) {
      _refreshData(forceRefresh: false);
    }
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (_isRefreshing) return;

    if (!AppInitState.servicesReady) {
      int attempts = 0;
      while (!AppInitState.servicesReady && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (mounted) setState(() => _isRefreshing = true);

    try {
      final essentialTasks = [
        _loadBanners(forceRefresh: forceRefresh),
        _loadCategories(forceRefresh: forceRefresh),
      ];
      await Future.wait(essentialTasks);

      if (mounted && (_banners.isNotEmpty || _categories.isNotEmpty)) {
        setState(() => _isLoading = false);
      }

      final contentTasks = [
        _loadCourses(forceRefresh: forceRefresh),
        _loadBundles(forceRefresh: forceRefresh),
        _loadTips(forceRefresh: forceRefresh),
        _loadTeachers(forceRefresh: forceRefresh),
      ];

      final userTasks = [
        _loadEnrolledCourses(),
        _checkUnreadNotifications(),
      ];

      await Future.wait([...contentTasks, ...userTasks]);
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
        if (_bannerController.hasClients) {
          final nextPage = (_currentBannerPage + 1) % bannerCount;
          _bannerController
              .animateToPage(nextPage,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.linear)
              .then((_) {
            if (mounted) setState(() => _currentBannerPage = nextPage);
          });
        }
        if (_bottomBannerController.hasClients && _banners.isNotEmpty) {
          final nextBottomPage =
              (_currentBottomBannerPage + 1) % _banners.length;
          _bottomBannerController
              .animateToPage(nextBottomPage,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.linear)
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
      debugPrint('❌ Error loading teachers: $e');
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
          _banners = bannersData.map((e) => BannerAd.fromJson(e)).toList();
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
      debugPrint('❌ Error loading enrollment progress: $e');
    }
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: HomeDrawer(categories: _categories),
      backgroundColor: Win2K.windowBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Win2K Title Bar ──────────────────────────────────────
            _buildWin2KTitleBar(authService),

            // ── Win2K Toolbar ────────────────────────────────────────
            _buildWin2KToolbar(authService),

            // ── Status Bar (address bar style) ───────────────────────
            _buildAddressBar(),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshData(forceRefresh: true),
                color: Win2K.accent,
                backgroundColor: Win2K.silver,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_isLoading && _allCourses.isEmpty)
                      SliverToBoxAdapter(child: _buildWin2KLoading()),

                    if (!_isLoading || _allCourses.isNotEmpty) ...[
                      // Banner Carousel
                      _buildBannerCarousel(),

                      // Guest CTA
                      if (!authService.isAuthenticated)
                        _buildGuestBanner(isWideScreen),

                      // Continue Learning
                      SliverToBoxAdapter(child: _buildContinueLearning()),

                      // Categories
                      if (_categories.isNotEmpty) _buildCategoriesSection(),

                      // New Courses
                      if (_allCourses.isNotEmpty)
                        _buildNewCoursesSection(isWideScreen),

                      // Most Watched
                      if (_allCourses.isNotEmpty)
                        _buildMostWatchedSection(isWideScreen),

                      // Tips
                      _buildTipsSection(),

                      // Packages
                      _buildPackagesSection(isWideScreen),

                      // Bottom Banners
                      _buildBottomAdBanners(),

                      // Teachers
                      _buildTeachersSection(isWideScreen),

                      // Recorded Courses
                      if (_allCourses.isNotEmpty)
                        _buildRecordedCoursesSection(isWideScreen),
                    ],

                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                ),
              ),
            ),

            // ── Win2K Status Bar ─────────────────────────────────────
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  // ─── Win2K Title Bar ────────────────────────────────────────────────────────

  Widget _buildWin2KTitleBar(AuthService authService) {
    return Container(
      height: 28,
      decoration: Win2K.titleBar(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // App icon
          Container(
            width: 16,
            height: 16,
            color: Win2K.accent,
            child: const Icon(Icons.school, size: 12, color: Win2K.titleBarText),
          ),
          const SizedBox(width: 6),
          Text(
            'دوراتي - Doraty Learning Platform',
            style: Win2K.titleFont,
          ),
          const Spacer(),
          // Window control buttons
          _win2KWindowButton(Icons.minimize, onTap: () {}),
          const SizedBox(width: 2),
          _win2KWindowButton(Icons.crop_square, onTap: () {}),
          const SizedBox(width: 2),
          _win2KWindowButton(Icons.close, onTap: () {}, isClose: true),
        ],
      ),
    );
  }

  Widget _win2KWindowButton(IconData icon,
      {required VoidCallback onTap, bool isClose = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: isClose
            ? Win2K.raised(bg: const Color(0xFFD44040))
            : Win2K.raised(),
        child: Icon(icon, size: 10, color: Win2K.textDark),
      ),
    );
  }

  // ─── Win2K Menu Bar / Toolbar ────────────────────────────────────────────────

  Widget _buildWin2KToolbar(AuthService authService) {
    return Container(
      height: 26,
      decoration: const BoxDecoration(
        color: Win2K.silver,
        border: Border(
          bottom: BorderSide(color: Win2K.shadow, width: 1),
        ),
      ),
      child: Row(
        children: [
          _menuBarItem('File'),
          _menuBarItem('View'),
          _menuBarItem('Favorites'),
          _menuBarItem('Tools'),
          _menuBarItem('Help'),
          const VerticalDivider(width: 1, color: Win2K.shadow),
          const SizedBox(width: 6),
          // Toolbar icons
          _toolbarIconBtn(Icons.arrow_back,
              onTap: () => Navigator.maybePop(context)),
          _toolbarIconBtn(Icons.refresh,
              onTap: () => _refreshData(forceRefresh: true)),
          _toolbarIconBtn(Icons.home_outlined,
              onTap: () => context.go('/courses')),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 20,
            color: Win2K.shadow,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: Win2K.raised(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu, size: 13, color: Win2K.textDark),
                  const SizedBox(width: 4),
                  Text('Menu', style: Win2K.sysFont),
                  const Icon(Icons.arrow_drop_down,
                      size: 14, color: Win2K.textDark),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (!authService.isAuthenticated) ...[
            GestureDetector(
              onTap: () => context.push('/login'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: Win2K.raised(bg: Win2K.accent),
                child: Text(
                  _t('login_title'),
                  style:
                      Win2K.sysFont.copyWith(color: Win2K.titleBarText),
                ),
              ),
            ),
          ] else ...[
            _toolbarIconBtn(Icons.shopping_cart_outlined,
                onTap: () => context.push('/cart')),
            Stack(
              children: [
                _toolbarIconBtn(Icons.notifications_outlined,
                    onTap: () => context.push('/notifications')),
                if (_hasUnreadNotifications)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF0000),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            _toolbarIconBtn(
                Provider.of<ThemeProvider>(context).isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onTap: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            }),
          ],
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _menuBarItem(String label) {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: Win2K.sysFont),
      ),
    );
  }

  Widget _toolbarIconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: Win2K.raised(),
        child: Icon(icon, size: 14, color: Win2K.textDark),
      ),
    );
  }

  // ─── Address Bar ─────────────────────────────────────────────────────────────

  Widget _buildAddressBar() {
    return Container(
      height: 26,
      color: Win2K.silver,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Text('Address:', style: Win2K.sysFont),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Provider.of<NavigationProvider>(context, listen: false)
                    .setIndex(1, focusSearch: true);
                context.go('/courses');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: Win2K.sunken(),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 12, color: Win2K.textGray),
                    const SizedBox(width: 4),
                    Hero(
                      tag: 'search_bar',
                      child: Text(
                        _t('search_hint'),
                        style: Win2K.sysFont.copyWith(color: Win2K.textGray),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: Win2K.raised(),
            child: Text('Go', style: Win2K.sysFont),
          ),
        ],
      ),
    );
  }

  // ─── Loading State ───────────────────────────────────────────────────────────

  Widget _buildWin2KLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Win2K.sunken(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.hourglass_empty,
                        size: 16, color: Win2K.textDark),
                    const SizedBox(width: 8),
                    Text('Loading content, please wait...',
                        style: Win2K.sysFont),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 16,
                  decoration: Win2K.sunken(bg: Win2K.white),
                  child: const LinearProgressIndicator(
                    backgroundColor: Win2K.white,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Win2K.progressBar),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ShimmerLoader.rectangular(height: 140),
          const SizedBox(height: 12),
          ShimmerLoader.rectangular(height: 24, width: 150),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ShimmerLoader.circular(height: 55, width: 55),
                    const SizedBox(height: 6),
                    ShimmerLoader.rectangular(height: 10, width: 50),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CourseCardShimmer(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Banner Carousel ─────────────────────────────────────────────────────────

  Widget _buildBannerCarousel() {
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

    if (bannerItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: 'Featured',
        child: Column(
          children: [
            // Banner window chrome
            Container(
              decoration: Win2K.sunken(),
              height: 175,
              child: PageView.builder(
                controller: _bannerController,
                onPageChanged: (i) => setState(() => _currentBannerPage = i),
                itemCount: bannerItems.length,
                itemBuilder: (ctx, i) => _buildBannerItem(bannerItems[i]),
              ),
            ),
            // Navigation dots styled as Win2K tabs
            Container(
              color: Win2K.silver,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  bannerItems.length,
                  (i) => GestureDetector(
                    onTap: () {
                      _bannerController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                      );
                    },
                    child: Container(
                      width: 16,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: _currentBannerPage == i
                          ? BoxDecoration(
                              color: Win2K.accent,
                              border: Border.all(color: Win2K.shadow),
                            )
                          : Win2K.raised(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerItem(BannerAd item) {
    return GestureDetector(
      onTap: () => _handleBannerTap(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, url) =>
                Container(color: Win2K.silver),
            errorWidget: (ctx, url, e) => Container(
              color: Win2K.silver,
              child: const Center(
                child: Icon(Icons.broken_image, color: Win2K.shadow),
              ),
            ),
          ),
          // Classic Win2K overlay with banner title
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Win2K.titleBarStart.withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Win2K.titleFont.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: Win2K.raised(),
                    child: Text(
                      item.subtitle?.isNotEmpty == true
                          ? item.subtitle!
                          : 'Open',
                      style: Win2K.sysFont,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      final identifier =
          course.slug.isNotEmpty ? course.slug : course.id;
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

  // ─── Guest Banner ────────────────────────────────────────────────────────────

  Widget _buildGuestBanner(bool isWideScreen) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          decoration: Win2K.raised(bg: Win2K.silverLight),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: Win2K.sunken(),
                child: const Icon(Icons.info_outline,
                    size: 28, color: Win2K.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انضم إلى مجتمع دوراتي!',
                      style:
                          Win2K.sysFont.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سجل الآن كطالب لتتعلم مهارات جديدة، أو كمدرب لتنشر دوراتك.',
                      style: Win2K.sysFont,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Win2KButton(
                          label: 'إنشاء حساب',
                          onPressed: () => context.push('/register'),
                          color: Win2K.accent,
                          textColor: Win2K.titleBarText,
                        ),
                        const SizedBox(width: 8),
                        Win2KButton(
                          label: 'تسجيل دخول',
                          onPressed: () => context.push('/login'),
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

  // ─── Continue Learning ────────────────────────────────────────────────────────

  Widget _buildContinueLearning() {
    final enrolledCourses =
        _allCourses.where((c) => _enrolledCourseIds.contains(c.id)).toList();
    if (enrolledCourses.isEmpty) return const SizedBox.shrink();

    final lastCourse = enrolledCourses.first;
    final progress = (_enrollmentProgress[lastCourse.id] ?? 0.0) / 100;

    return Win2KGroupBox(
      title: _t('continue_learning'),
      child: Container(
        color: Win2K.white,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              decoration: Win2K.sunken(),
              child: CachedNetworkImage(
                imageUrl: lastCourse.imageUrl ?? '',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.school, color: Win2K.shadow),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lastCourse.getLocalizedTitle(
                        Provider.of<LocaleProvider>(context).locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Win2K.sysFont.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t('completed')} ${(_enrollmentProgress[lastCourse.id] ?? 0.0).toStringAsFixed(0)}%',
                    style: Win2K.sysFont.copyWith(color: Win2K.textGray),
                  ),
                  const SizedBox(height: 6),
                  // Classic Win2K progress bar
                  Container(
                    height: 14,
                    decoration: Win2K.sunken(),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        color: Win2K.progressBar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Win2KButton(
              label: 'Resume',
              icon: Icons.play_arrow,
              onPressed: () {
                final identifier = lastCourse.slug.isNotEmpty
                    ? lastCourse.slug
                    : lastCourse.id;
                context.push('/course/$identifier');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Categories Section ───────────────────────────────────────────────────────

  Widget _buildCategoriesSection() {
    final parentCats =
        _categories.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('categories_title'),
        onSeeAll: () => context.push('/topics'),
        seeAllLabel: _t('explore_more'),
        child: Container(
          color: Win2K.white,
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            itemCount: parentCats.length,
            itemBuilder: (context, index) {
              final cat = parentCats[index];
              final colors = AppColors.categoryCardColors;
              final color = colors[index % colors.length];
              return GestureDetector(
                onTap: () => context.go('/courses?categoryId=${cat.id}'),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: Win2K.raised(bg: Win2K.silver),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.name,
                        style:
                            Win2K.sysFont.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Courses Sections ─────────────────────────────────────────────────────────

  Widget _buildNewCoursesSection(bool isWideScreen) {
    final newCourses = List<Course>.from(_allCourses);
    newCourses.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('new_courses'),
        onSeeAll: () => context.push('/courses'),
        seeAllLabel: _t('explore_more'),
        child: SizedBox(
          height: isWideScreen ? 350 : 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            itemCount: newCourses.take(10).length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: isWideScreen ? 300 : 260,
                child: _wrapCourseCard(CourseCard(
                    course: newCourses[index],
                    heroTag: 'new_${newCourses[index].id}')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMostWatchedSection(bool isWideScreen) {
    final mostWatched = List<Course>.from(_allCourses);
    mostWatched.sort((a, b) => b.studentsCount.compareTo(a.studentsCount));

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('most_watched'),
        onSeeAll: () => context.push('/courses'),
        seeAllLabel: _t('explore_more'),
        child: SizedBox(
          height: isWideScreen ? 350 : 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            itemCount: mostWatched.take(10).length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: isWideScreen ? 300 : 260,
                child: _wrapCourseCard(CourseCard(
                    course: mostWatched[index],
                    heroTag: 'watched_${mostWatched[index].id}')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordedCoursesSection(bool isWideScreen) {
    final recordedCourses = List<Course>.from(_allCourses);
    if (recordedCourses.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('recorded_courses'),
        onSeeAll: () => context.push('/courses'),
        seeAllLabel: _t('explore_more'),
        child: SizedBox(
          height: isWideScreen ? 350 : 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            itemCount: recordedCourses.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: isWideScreen ? 300 : 260,
                child: _wrapCourseCard(CourseCard(
                    course: recordedCourses[index],
                    heroTag: 'recorded_${recordedCourses[index].id}')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps a course card in Win2K styling (raised border)
  Widget _wrapCourseCard(Widget card) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Win2K.white, width: 1),
          left: const BorderSide(color: Win2K.white, width: 1),
          bottom: const BorderSide(color: Win2K.darkShadow, width: 1),
          right: const BorderSide(color: Win2K.darkShadow, width: 1),
        ),
      ),
      child: card,
    );
  }

  // ─── Tips Section ─────────────────────────────────────────────────────────────

  Widget _buildTipsSection() {
    if (_tips.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('learning_tips_title'),
        onSeeAll: () => context.push('/tips'),
        seeAllLabel: _t('explore_more'),
        child: SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            itemCount: _tips.length,
            itemBuilder: (context, index) {
              final tip = _tips[index];
              return Container(
                margin: const EdgeInsets.only(right: 6),
                decoration: Win2K.raised(),
                child: TipPreviewCard(
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Packages Section ────────────────────────────────────────────────────────

  Widget _buildPackagesSection(bool isWideScreen) {
    if (_bundles.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale;

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('bundles_title'),
        onSeeAll: () => context.push('/packages'),
        seeAllLabel: _t('explore_more'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(6),
                itemCount: _bundles.length,
                itemBuilder: (context, index) {
                  final bundle = _bundles[index];
                  final bundleCourseIds =
                      bundle.courses.map((c) => c.id).toList();
                  final bool hasBundleAccess =
                      bundleCourseIds.isNotEmpty &&
                          bundleCourseIds.every(_accessibleCourseIds.contains);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PackageScreen(
                            packageTitle: bundle.title,
                            courses: bundle.courses,
                            bundle: bundle,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: Win2K.raised(bg: Win2K.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bundle icon header (Win2K style)
                          Container(
                            height: 40,
                            decoration: Win2K.titleBar(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.library_books,
                                    size: 14, color: Win2K.titleBarText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    bundle.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Win2K.sysFont.copyWith(
                                        color: Win2K.titleBarText,
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Image
                          if (bundle.imageUrl != null &&
                              bundle.imageUrl!.isNotEmpty)
                            Container(
                              height: 80,
                              decoration: Win2K.sunken(),
                              child: CachedNetworkImage(
                                imageUrl: bundle.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.image,
                                      color: Win2K.shadow),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${bundle.courses.length} courses',
                                    style: Win2K.sysFont
                                        .copyWith(color: Win2K.textGray),
                                  ),
                                  if (bundle.price > 0)
                                    Text(
                                      bundle.getFormattedPrice(locale),
                                      style: Win2K.sysFont.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Win2K.accent),
                                    ),
                                  Container(
                                    width: double.infinity,
                                    decoration: Win2K.raised(
                                        bg: hasBundleAccess
                                            ? Win2K.greenSuccess
                                            : Win2K.accent),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Text(
                                      hasBundleAccess ? 'أكمل' : 'اشترك',
                                      textAlign: TextAlign.center,
                                      style: Win2K.sysFont.copyWith(
                                          color: Win2K.titleBarText,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // See All button in classic Win2K style
            Container(
              color: Win2K.silver,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Win2KButton(
                    label: 'View All Packages...',
                    onPressed: () => context.push('/packages'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Ad Banners ────────────────────────────────────────────────────────

  Widget _buildBottomAdBanners() {
    final bottomBanners =
        _banners.where((b) => b.location == 'bottom').toList();
    if (bottomBanners.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: 'Advertisements',
        child: Container(
          decoration: Win2K.sunken(),
          height: 150,
          child: PageView.builder(
            controller: _bottomBannerController,
            onPageChanged: (i) =>
                setState(() => _currentBottomBannerPage = i),
            itemCount: bottomBanners.length,
            itemBuilder: (context, index) {
              final item = bottomBanners[index];
              final isLottie =
                  item.imageUrl.toLowerCase().endsWith('.json') ||
                      item.imageUrl.toLowerCase().endsWith('.lottie');
              return GestureDetector(
                onTap: () => _handleBannerTap(item),
                child: isLottie
                    ? Lottie.network(item.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Win2K.silver))
                    : CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Win2K.silver),
                        errorWidget: (_, __, ___) =>
                            Container(color: Win2K.silver),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Teachers Section ─────────────────────────────────────────────────────────

  Widget _buildTeachersSection(bool isWideScreen) {
    if (_filteredTeachers.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Win2KGroupBox(
        title: _t('top_teachers'),
        onSeeAll: () => context.push('/teachers'),
        seeAllLabel: _t('explore_more'),
        child: SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: _filteredTeachers.take(12).length,
            itemBuilder: (context, index) =>
                _buildTeacherItem(_filteredTeachers[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherItem(Map<String, dynamic> teacher) {
    final dynamic usersRaw = teacher['users'];
    final Map<String, dynamic>? userData =
        usersRaw is Map ? SafeParser.safeMap(usersRaw) : null;
    final name = StringUtils.cleanTeacherName(
        userData?['full_name'] ??
            userData?['name'] ??
            teacher['full_name'] ??
            teacher['name'] ??
            _t('teacher'));
    final avatarUrl = userData?['photo_url'] ??
        userData?['avatar_url'] ??
        teacher['photo_url'] ??
        teacher['avatar_url'];

    return GestureDetector(
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
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: Win2K.raised(bg: Win2K.white),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: Win2K.sunken(),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                    ? (avatarUrl.toString().startsWith('data:')
                        ? Image.memory(
                            StringUtils.decodeBase64Image(avatarUrl.toString()),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          )
                        : CachedNetworkImage(
                            imageUrl: avatarUrl.toString(),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _defaultAvatar(),
                            errorWidget: (_, __, ___) => _defaultAvatar(),
                          ))
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Win2K.sysFont.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 52,
      height: 52,
      color: Win2K.silver,
      child: const Icon(Icons.person, color: Win2K.shadow, size: 28),
    );
  }

  // ─── Status Bar ──────────────────────────────────────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      height: 20,
      decoration: const BoxDecoration(
        color: Win2K.silver,
        border: Border(top: BorderSide(color: Win2K.shadow, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 1,
            height: 14,
            color: Win2K.shadow,
          ),
          const SizedBox(width: 6),
          Text(
            _isRefreshing ? 'Refreshing...' : 'Done',
            style: Win2K.sysFont.copyWith(fontSize: 11),
          ),
          const Spacer(),
          Container(
            width: 1,
            height: 14,
            color: Win2K.shadow,
          ),
          const SizedBox(width: 6),
          Text(
            '${_allCourses.length} courses',
            style: Win2K.sysFont.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 6),
          Container(
            width: 1,
            height: 14,
            color: Win2K.shadow,
          ),
          const SizedBox(width: 6),
          Text(
            'دوراتي™ v2.0',
            style: Win2K.sysFont.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
