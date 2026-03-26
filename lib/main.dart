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
import 'widgets/dynamic_gradient_background.dart';
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
import 'package:flutter_web_plugins/url_strategy.dart'; // Ensure proper URL strategy
import 'core/routing/app_router.dart';
import 'package:go_router/go_router.dart';

void main() {
  // Use runZonedGuarded for production safety
  runZonedGuarded(() async {
    // 1. Minimum possible setup to reach runApp quickly
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy(); // Use Path URL Strategy
    
    // 2. Parallelize critical initializations
    try {
      // 1. Critical Base Services
      await Hive.initFlutter().timeout(Duration(seconds: 7));
      await LocalDatabase().init().timeout(Duration(seconds: 7));
      await SettingsService().init().timeout(Duration(seconds: 5));
      debugPrint('✅ Storage/Settings initialized');
    } catch (e) {
      debugPrint('🚨 [StorageError] Storage/Settings initialization failed: $e');
    }

    try {
      // 2. Optional/Env Loading
      await dotenv.load(fileName: ".env").timeout(Duration(seconds: 3));
      debugPrint('✅ Environment loaded');
    } catch (e) {
      debugPrint('⚠️ [EnvError] Environment loading failed (expected if .env missing): $e');
    }

    // 3. Initialize Supabase with a timeout safeguard

    const String ciUrl = String.fromEnvironment('SUPABASE_URL');
    const String ciAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final String url = (ciUrl.isNotEmpty ? ciUrl : Env.supabaseUrl).trim();
    final String anonKey = (ciAnonKey.isNotEmpty ? ciAnonKey : Env.supabaseAnonKey).trim();

    try {
      await SupabaseService.initialize(
        supabaseUrl: url,
        supabaseAnonKey: anonKey,
      ).timeout(Duration(seconds: 10));
      debugPrint('✅ Supabase initialized');
    } catch (e) {
      debugPrint('⚠️ Supabase Init failed or timed out: $e');
    }

    // 4. Background Services (Non-blocking)
    SyncService().init(skipInitialSync: kIsWeb);
    if (!kIsWeb) {
      NotificationService().init();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // 5. Start the App
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
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('🚨 [ZoneError] $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp.router(
          title: 'منصة دوراتي',
          debugShowCheckedModeBanner: false,

          // Localization Support
          locale: localeProvider.flutterLocale,
          supportedLocales: [
            Locale('ar', 'SY'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.materialThemeMode,

          // Router mapping
          routerConfig: appRouter,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final Widget? child;
  final GoRouterState? routeState;

  const MainScreen({super.key, this.child, this.routeState});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _calculateSelectedIndex(BuildContext context) {
    if (widget.routeState == null) {
      final String location = GoRouterState.of(context).uri.path;
      if (location.startsWith('/courses')) return 1;
      if (location.startsWith('/tips')) return 2;
      if (location.startsWith('/topics')) return 3;
      if (location.startsWith('/profile')) return 4;
      return 0; // '/'
    }

    final String location = widget.routeState!.uri.path;
    if (location.startsWith('/courses')) return 1;
    if (location.startsWith('/tips')) return 2;
    if (location.startsWith('/topics')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

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
    final int currentIndex = _calculateSelectedIndex(context);

    void onItemTapped(int index, BuildContext context) {
      navProvider.setIndex(index);
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/courses');
          break;
        case 2:
          context.go('/tips');
          break;
        case 3:
          context.go('/topics');
          break;
        case 4:
          context.go('/profile');
          break;
      }
    }

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          // Offline Indicator (Condition: syncService.isOffline)
          Consumer<SyncService>(
            builder: (context, sync, _) {
              if (!sync.isOffline) return SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange.shade800,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: AppColors.getTextColor(context)),
                    SizedBox(width: 8),
                    Text(
                      AppStrings.get('offline_mode', context.read<LocaleProvider>().locale),
                      style: TextStyle(color: AppColors.getTextColor(context), fontSize: 12, fontWeight: FontWeight.bold),
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
                          color: AppColors.getMutedTextColor(context),
                          width: 1,
                        ),
                      ),
                    ),
                    child: NavigationRail(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        onItemTapped(index, context);
                      },
                      backgroundColor:
                          AppColors.getSurfaceColor(context).withOpacity(0.95),
                      indicatorColor: AppColors.primaryPurple.withOpacity(0.2),
                      labelType: NavigationRailLabelType.all,
                      useIndicator: true,
                      minWidth: 80,
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon:
                              Icon(Icons.home, color: AppColors.primaryPurple),
                          label: Text('الرئيسية', style: TextStyle(fontSize: 12)),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.manage_search_outlined),
                          selectedIcon:
                              Icon(Icons.search, color: AppColors.primaryPurple),
                          label: Consumer<LocaleProvider>(
                            builder: (context, localeProvider, _) => Text(
                              AppStrings.get('search', localeProvider.locale),
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.lightbulb_outline),
                          selectedIcon:
                              Icon(Icons.lightbulb, color: AppColors.primaryPurple),
                          label: Text('نصائح', style: TextStyle(fontSize: 12)),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.category_outlined),
                          selectedIcon:
                              Icon(Icons.category, color: AppColors.primaryPurple),
                          label: Consumer<LocaleProvider>(
                              builder: (context, localeProvider, _) => Text(
                                    AppStrings.get(
                                        'categories_title', localeProvider.locale),
                                    style: TextStyle(fontSize: 12),
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
                                    BoxDecoration(shape: BoxShape.circle),
                                child: ClipOval(
                                  child: (auth.isAuthenticated && photoUrl != null)
                                      ? Image.network(photoUrl, fit: BoxFit.cover)
                                      : Icon(Icons.person_outline),
                                ),
                              );
                            },
                          ),
                          label: Text('حسابي', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 1200),
                      child: DynamicGradientBackground(
                        child: widget.child ?? _buildCurrentScreen(currentIndex),
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
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.none,
                      child: CurvedNavigationBar(
                        index: currentIndex > 4 ? 0 : currentIndex,
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
                        animationDuration: Duration(milliseconds: 300),
                        onTap: (index) {
                          onItemTapped(index, context);
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
        return HomeScreen();
      case 1:
        return ExploreScreen();
      case 2:
        return AllTipsScreen(showAppBar: false, isVisible: true, showCloseButton: false);
      case 3:
        return SubjectsScreen(showBackButton: false);
      case 4:
        return ProfileScreen();
      default:
        return HomeScreen();
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
