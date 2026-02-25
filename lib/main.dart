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
import 'core/services/app_update_service.dart';

void main() async {
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

  // Initialize Notification Service - AFTER Supabase
  await NotificationService().init();

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
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            ExploreScreen(),
            CoursesListScreen(showBackButton: false),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          // final lang = localeProvider.locale;
          return CurvedNavigationBar(
            index: _currentIndex,
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
              Icon(Icons.play_circle_outline,
                  size: 30,
                  color: _currentIndex == 2
                      ? Colors.white
                      : AppColors.primaryPurple),
              Icon(Icons.person_outline,
                  size: 30,
                  color: _currentIndex == 3
                      ? Colors.white
                      : AppColors.primaryPurple),
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
          );
        },
      ),
    );
  }
}
