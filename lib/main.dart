import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'screens/home/home_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/courses/courses_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/gradient_background.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/env/multi_env.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

import 'models/download.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/settings_service.dart';
import 'core/localization/locale_provider.dart';
// import 'core/constants/app_strings.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/offline_course.dart';
import 'models/offline_lesson.dart';
import 'core/services/sync_service.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'core/services/notification_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/app_update_service.dart';
import 'core/utils/url_strategy_noop.dart'
    if (dart.library.html) 'core/utils/url_strategy_web.dart';

void main() async {
  // Use path URL strategy for clean URLs on web
  configureUrlStrategy();
  
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(DownloadedLessonAdapter());
  Hive.registerAdapter(DownloadStatusAdapter());
  Hive.registerAdapter(OfflineCourseAdapter());
  Hive.registerAdapter(OfflineLessonAdapter());

  // Initialize DownloadManager
  await DownloadManager().init();

  // Initialize OfflineCacheService
  await OfflineCacheService().init();

  // Initialize SettingsService
  await SettingsService().init();

  // Initialize Supabase
  // In CI/GitHub Actions builds, SUPABASE_URL & SUPABASE_ANON_KEY are injected
  // via --dart-define. Locally (debug / Windows), they will be empty strings,
  // so we fall back to the envied-generated Env class which reads from .env file.
  const String ciUrl = String.fromEnvironment('SUPABASE_URL');
  const String ciAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final String url = (ciUrl.isNotEmpty ? ciUrl : Env.supabaseUrl).trim();
  final String anonKey =
      (ciAnonKey.isNotEmpty ? ciAnonKey : Env.supabaseAnonKey).trim();

  // Initialize Supabase with the configuration
  try {
    debugPrint('🔄 Initializing Supabase...');
    debugPrint('📍 URL: $url');

    await SupabaseService.initialize(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
    );

    debugPrint('✅ Supabase initialized successfully');
    debugPrint('🔌 Client connected successfully');
  } catch (e) {
    debugPrint(
        '⚠️ WARNING: Failed to initialize Supabase. The app will continue in OFFLINE mode.');
    debugPrint('Error: $e');
    // debugPrint('StackTrace: $stackTrace');
    
    // We don't return early here anymore, allowing the app to run in offline mode
  }

  // Initialize SyncService (Background) - AFTER Supabase
  SyncService().init();

  // Initialize Notification Service - AFTER Supabase (Non-blocking)
  NotificationService().init();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Allow all orientations for video fullscreen
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'منصة دوراتي',
          debugShowCheckedModeBanner: false,

          // Localization Support
          locale: localeProvider.flutterLocale,
          supportedLocales: const [
            Locale('ar', 'SY'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.materialThemeMode,

          // Home
          home: const SplashScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check for updates after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService().checkForUpdates(context);
    });
  }


  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;
    final authService = Provider.of<AuthService>(context);
    final userRole = authService.userProfile?['role'] ??
        (authService.userProfile?['is_admin'] == true ? 'admin' : 'student');

    final bool isManager = userRole == 'teacher' ||
        userRole == 'admin' ||
        userRole == 'super_admin';

    // Build common screens
    final List<Widget> screens = [
      const HomeScreen(),
      const ExploreScreen(),
      if (isManager) ...[
        userRole == 'teacher'
            ? const TeacherDashboardScreen()
            : const AdminDashboardScreen(),
      ],
      const CoursesListScreen(showBackButton: false),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Row(
        children: [
          if (isWideScreen)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor:
                    AppColors.getSurfaceColor(context).withOpacity(0.95),
                indicatorColor: AppColors.primaryPurple.withOpacity(0.2),
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                minWidth: 80,
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon:
                        Icon(Icons.home, color: AppColors.primaryPurple),
                    label: Text('الرئيسية', style: TextStyle(fontSize: 12)),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.manage_search_outlined),
                    selectedIcon:
                        Icon(Icons.search, color: AppColors.primaryPurple),
                    label: Text('استكشف', style: TextStyle(fontSize: 12)),
                  ),
                  if (isManager)
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard,
                          color: AppColors.primaryPurple),
                      label: Text('لوحة التحكم', style: TextStyle(fontSize: 12)),
                    ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.play_circle_outline),
                    selectedIcon:
                        Icon(Icons.play_circle, color: AppColors.primaryPurple),
                    label: Text('دوراتي', style: TextStyle(fontSize: 12)),
                  ),
                  NavigationRailDestination(
                    icon: Consumer<AuthService>(
                      builder: (context, auth, _) {
                        final photoUrl = auth.userProfile?['avatar_url'] ??
                            auth.userProfile?['photo_url'];
                        return Container(
                          width: 30,
                          height: 30,
                          decoration:
                              const BoxDecoration(shape: BoxShape.circle),
                          child: ClipOval(
                            child: (auth.isAuthenticated && photoUrl != null)
                                ? Image.network(photoUrl, fit: BoxFit.cover)
                                : const Icon(Icons.person_outline),
                          ),
                        );
                      },
                    ),
                    label: const Text('حسابي', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: GradientBackground(
                  child: IndexedStack(
                    index: _currentIndex >= screens.length ? 0 : _currentIndex,
                    children: screens,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return SafeArea(
                  bottom: true,
                  child: CurvedNavigationBar(
                    index: _currentIndex >= screens.length ? 0 : _currentIndex,
                    height: 60.0,
                    items: <Widget>[
                      Icon(Icons.home_outlined,
                          size: 30,
                          color: _currentIndex == 0
                              ? Colors.white
                              : AppColors.primaryPurple),
                      Icon(Icons.manage_search_outlined,
                          size: 30,
                          color: _currentIndex == 1
                              ? Colors.white
                              : AppColors.primaryPurple),
                      if (isManager)
                        Icon(Icons.dashboard_outlined,
                            size: 30,
                            color: _currentIndex == 2
                                ? Colors.white
                                : AppColors.primaryPurple),
                      Icon(Icons.play_circle_outline,
                          size: 30,
                          color: _currentIndex == (isManager ? 3 : 2)
                              ? Colors.white
                              : AppColors.primaryPurple),
                      Consumer<AuthService>(
                        builder: (context, auth, _) {
                          final photoUrl = auth.userProfile?['avatar_url'] ??
                              auth.userProfile?['photo_url'];
                          final profileIndex = isManager ? 4 : 3;
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: _currentIndex == profileIndex
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: ClipOval(
                              child: (auth.isAuthenticated && photoUrl != null)
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                              stackTrace) =>
                                          Icon(Icons.person_outline,
                                              size: 30,
                                              color: _currentIndex == profileIndex
                                                  ? Colors.white
                                                  : AppColors.primaryPurple),
                                    )
                                  : Icon(Icons.person_outline,
                                      size: 30,
                                      color: _currentIndex == profileIndex
                                          ? Colors.white
                                          : AppColors.primaryPurple),
                            ),
                          );
                        },
                      ),
                    ],
                    color: AppColors.getSurfaceColor(context).withOpacity(0.95),
                    buttonBackgroundColor: AppColors.primaryPurple,
                    backgroundColor: Colors.transparent,
                    animationCurve: Curves.easeInOut,
                    animationDuration: const Duration(milliseconds: 300),
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    letIndexChange: (index) => true,
                  ),
                );
              },
            ),
    );
  }
}
