import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'screens/home/home_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/tips/all_tips_screen.dart';
import 'screens/categories/subjects_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/gradient_background.dart';
import 'core/providers/navigation_provider.dart';
import 'core/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/env/multi_env.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/settings_service.dart';
import 'core/localization/locale_provider.dart';
import 'core/services/local_database.dart';
import 'package:doraty/core/constants/app_strings.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/sync_service.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'core/services/notification_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/app_update_service.dart';
import 'core/utils/url_strategy_noop.dart'
    if (dart.library.html) 'core/utils/url_strategy_web.dart';

void main() {
  runZonedGuarded(() async {
    // Use path URL strategy for clean URLs on web
    configureUrlStrategy();
    
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Global Flutter error handler
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('🚨 [FlutterError] ${details.exception}\n${details.stack}');
    };
  // We initialize Hive first as it's a prerequisite for some adapters
  await Hive.initFlutter();
  // Initialize LocalDatabase first as it's a prerequisite for some services
  await LocalDatabase().init();

  final List<Future> remainingInitializations = [
    SettingsService().init(),
  ];

  if (!kIsWeb) {
  }


  await Future.wait(remainingInitializations);

  // Initialize Supabase
  const String ciUrl = String.fromEnvironment('SUPABASE_URL');
  const String ciAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final String url = (ciUrl.isNotEmpty ? ciUrl : Env.supabaseUrl).trim();
  final String anonKey =
      (ciAnonKey.isNotEmpty ? ciAnonKey : Env.supabaseAnonKey).trim();

  try {
    debugPrint('🔄 Initializing Supabase...');
    await SupabaseService.initialize(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
    );
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ WARNING: Failed to initialize Supabase. The app will continue in OFFLINE mode.');
    debugPrint('Error: $e');
  }

  // Initialize SyncService (Background) - AFTER Supabase
  SyncService().init(skipInitialSync: kIsWeb);

  // Initialize Notification Service - AFTER Supabase (Non-blocking)
  if (!kIsWeb) {
    NotificationService().init();
  }

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
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const MyApp(),
    ),
  );
  }, (error, stack) {
    // Zone-level error catcher — catches async errors missed by FlutterError
    debugPrint('🚨 [ZoneError] Unhandled: $error\n$stack');
  });
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for updates after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService().checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App Resumed: Triggering background sync...');
      SyncService().syncAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;

    final navProvider = Provider.of<NavigationProvider>(context);
    final int currentIndex = navProvider.currentIndex;

    // Build common screens
    final List<Widget> screens = [
      const HomeScreen(),
      const ExploreScreen(),
      AllTipsScreen(showAppBar: false, isVisible: currentIndex == 2, showCloseButton: false),
      const SubjectsScreen(showBackButton: false),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          // Offline Indicator (Condition: syncService.isOffline)
          Consumer<SyncService>(
            builder: (context, sync, _) {
              if (!sync.isOffline) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange.shade800,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get('offline_mode', context.read<LocaleProvider>().locale),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Row(
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
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        navProvider.setIndex(index);
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
                        NavigationRailDestination(
                          icon: const Icon(Icons.manage_search_outlined),
                          selectedIcon:
                              const Icon(Icons.search, color: AppColors.primaryPurple),
                          label: Consumer<LocaleProvider>(
                            builder: (context, localeProvider, _) => Text(
                              AppStrings.get('search', localeProvider.locale),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.lightbulb_outline),
                          selectedIcon:
                              Icon(Icons.lightbulb, color: AppColors.primaryPurple),
                          label: Text('نصائح', style: TextStyle(fontSize: 12)),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.category_outlined),
                          selectedIcon:
                              const Icon(Icons.category, color: AppColors.primaryPurple),
                          label: Consumer<LocaleProvider>(
                              builder: (context, localeProvider, _) => Text(
                                    AppStrings.get(
                                        'categories_title', localeProvider.locale),
                                    style: const TextStyle(fontSize: 12),
                                  )),
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
                      child: DynamicGradientBackground(
                        child: _buildCurrentScreen(currentIndex),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return SafeArea(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.none,
                      child: CurvedNavigationBar(
                        index: currentIndex >= screens.length ? 0 : currentIndex,
                        height: 60.0,
                        items: <Widget>[
                          _buildNavItem(Icons.home_outlined, 0, currentIndex),
                          _buildNavItem(Icons.manage_search_outlined, 1, currentIndex),
                          _buildNavItem(Icons.lightbulb_outline, 2, currentIndex),
                          _buildNavItem(Icons.category_outlined, 3, currentIndex),
                          _buildProfileTab(context, 4, currentIndex),
                        ],
                        color: AppColors.getSurfaceColor(context).withOpacity(0.95),
                        buttonBackgroundColor: AppColors.primaryPurple,
                        backgroundColor: Colors.transparent,
                        animationCurve: Curves.easeInOut,
                        animationDuration: const Duration(milliseconds: 300),
                        onTap: (index) {
                          navProvider.setIndex(index);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCurrentScreen(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ExploreScreen();
      case 2:
        return const AllTipsScreen(showAppBar: false, isVisible: true, showCloseButton: false);
      case 3:
        return const SubjectsScreen(showBackButton: false);
      case 4:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  Widget _buildNavItem(IconData icon, int index, int currentIndex) {
    bool isSelected = currentIndex == index;
    double iconSize = 26;
    
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: isSelected ? Colors.white : AppColors.primaryPurple,
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, int index, int currentIndex) {
    bool isSelected = currentIndex == index;
    double containerSize = 34;

    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final photoUrl = auth.userProfile?['avatar_url'] ?? auth.userProfile?['photo_url'];
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: ClipOval(
              child: (auth.isAuthenticated && photoUrl != null)
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person_outline,
                        size: 24,
                        color: isSelected ? Colors.white : AppColors.primaryPurple,
                      ),
                    )
                  : Icon(
                      Icons.person_outline,
                      size: 24,
                      color: isSelected ? Colors.white : AppColors.primaryPurple,
                    ),
            ),
          ),
        );
      },
    );
  }
}
