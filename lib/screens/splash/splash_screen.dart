import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/screen_security_service.dart';
import '../auth/role_selection_screen.dart';
import '../auth/login_screen.dart';
import '../../main.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

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
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // Check authentication status
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAuthenticated = authService.isAuthenticated;

      debugPrint(
          '🔐 Auth check: ${isAuthenticated ? "Authenticated" : "Not authenticated"}');

      if (isAuthenticated) {
        // Load user profile (handles caching internally now)
        await authService.loadUserProfile();
        
        // Wait a bit to ensure profile is loaded from cache/network
        final profile = authService.userProfile;
        final hasRole = profile != null && profile['role'] != null;

        // Apply screen security
        await _applyScreenSecurity();

        if (!mounted) return;
        
        if (!hasRole) {
          // If we are definitely online and have no role, go to selection
          // If we are offline and have no cached role, we're stuck anyway, but selection screen is better than nothing
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          );
        } else {
          // User is logged in and has a role (cached or fetched), go to main screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        // User is not logged in, go to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking auth status: $e');
      // On error, go to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _applyScreenSecurity() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      // Check if user is admin
      final response = await SupabaseService.instance.client
          .from('user_roles')
          .select('roles(name)')
          .eq('user_id', userId);

      final roles = response as List;
      final isAdmin = roles.any((role) {
        final roleData = role['roles'] as Map<String, dynamic>?;
        return roleData?['name'] == 'admin';
      });

      // Apply screen security based on role and app settings
      await ScreenSecurityService().applySecurityPolicy(isAdmin: isAdmin);
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
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
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
                              padding: const EdgeInsets.all(40),
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
                                  color: Colors.white.withOpacity(0.3),
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
                        const SizedBox(height: 30),
                        // App name
                        const Text(
                          'منصة دوراتي',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Subtitle
                        Text(
                          'رحلتك التعليمية تبدأ هنا',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 50),
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
