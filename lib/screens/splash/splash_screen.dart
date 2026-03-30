import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/screen_security_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/dynamic_gradient_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    // Main entry animations
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.7, curve: Curves.easeIn)),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic)),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
    );

    // Subtle breathing pulse for the logo
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _mainController.forward();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Shorter delay for Web as per user's preference for speed
    await Future.delayed(Duration(milliseconds: kIsWeb ? 800 : 2000));
    if (!mounted) return;

    try {
      await Future.any([
        _performAuthCheck(),
        Future.delayed(Duration(seconds: kIsWeb ? 10 : 20)).then((_) {
          if (mounted) context.go('/');
        }),
      ]);
    } catch (e) {
      if (mounted) context.go('/');
    }
  }

  Future<void> _performAuthCheck() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAuthenticated = authService.isAuthenticated;

    if (isAuthenticated) {
      try {
        await authService.loadUserProfile().timeout(const Duration(seconds: 5));
      } catch (_) {}
      
      try {
        final profile = authService.userProfile;
        final role = profile?['role'] as String?;
        await ScreenSecurityService().applySecurityPolicy(role: role).timeout(const Duration(seconds: 5));
      } catch (_) {
        await ScreenSecurityService().enableScreenSecurity();
      }
      
      if (mounted) context.go('/');
    } else {
      if (mounted) context.go('/');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with Pulse & Glassmorphism
              AnimatedBuilder(
                animation: Listenable.merge([_mainController, _pulseController]),
                builder: (context, child) {
                  final pulseValue = 1.0 + (_pulseController.value * 0.03);
                  return FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale.drive(Tween<double>(begin: 1.0, end: pulseValue)),
                      child: Container(
                        padding: const EdgeInsets.all(35),
                        decoration: BoxDecoration(
                          color: AppColors.getGlassColor(context, opacity: 0.2),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: AppColors.getGlassColor(context, opacity: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // App Name (Slide & Fade)
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Text(
                    'منصة دوراتي',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: AppColors.getTextColor(context),
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.15),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              FadeTransition(
                opacity: _subtitleOpacity,
                child: Text(
                  'رحلتك التعليمية تبدأ هنا',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Cairo',
                    color: AppColors.getTextColor(context).withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Premium Glowing Dots Loader
              _buildModernLoader(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernLoader() {
    return FadeTransition(
      opacity: _subtitleOpacity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final delay = index * 0.33;
              final value = (math.sin((_pulseController.value * 2 * math.pi) + (delay * 2 * math.pi)) + 1) / 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withOpacity(0.3 + (value * 0.7)),
                  boxShadow: [
                    if (value > 0.5)
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(value * 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
