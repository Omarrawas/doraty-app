import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/screen_security_service.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // Check authentication status
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for minimum splash duration (animation)
    await Future.delayed(Duration(milliseconds: 2000));

    if (!mounted) return;

    try {
      // Use a global timeout for the entire auth/init sequence on splash screen
      // If something takes more than 10 seconds, we fallback to guest mode or MainScreen
      await Future.any([
        _performAuthCheck(),
        Future.delayed(Duration(seconds: 15)).then((_) {
          debugPrint('⚠️ SplashScreen: Init sequence TIMED OUT. Proceeding to main...');
          if (mounted) {
            context.go('/');
          }
        }),
      ]);
    } catch (e) {
      debugPrint('❌ Error in splash screen sequence: $e');
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<void> _performAuthCheck() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAuthenticated = authService.isAuthenticated;

    debugPrint('🔐 Auth status: ${isAuthenticated ? "Logged In" : "Guest"}');

    if (isAuthenticated) {
      // Load user profile with timeout
      try {
        await authService.loadUserProfile().timeout(Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Profile load timed out: $e');
      }
      
      // Removed role-check forced registration; we now always go to the home screen
      // even for accounts with incomplete profiles to allow guest-like access.

      // Apply screen security with timeout
      try {
        await _applyScreenSecurity().timeout(Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Security check timed out: $e');
      }

      if (!mounted) return;
      
      // If we are authenticated but have no role, we still allow them to go to the home screen
      // as a guest/incomplete user. They can finish registration from the profile screen.
      // This respects the user's request to not be forced to the registration page on startup.
      context.go('/');
    } else {
      // Not authenticated
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<void> _applyScreenSecurity() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profile = authService.userProfile;
      final role = profile?['role'] as String?;

      // Apply screen security based on role and app settings (handled by service)
      await ScreenSecurityService().applySecurityPolicy(role: role);
    } catch (e) {
      debugPrint('⚠️ Error applying screen security: $e');
      // On error, enable security by default for safety
      await ScreenSecurityService().enableScreenSecurity();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with glassmorphism
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.getMutedTextColor(context),
                                  width: 1.5,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 100,
                                height: 100,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        // App name
                        Text(
                          'منصة دوراتي',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 10),
                        // Subtitle
                        Text(
                          'رحلتك التعليمية تبدأ هنا',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.getTextColor(context, secondary: true),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 50),
                        // Loading indicator
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.8),
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
