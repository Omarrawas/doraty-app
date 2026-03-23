import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/screen_security_service.dart';
import 'register_screen.dart';
import '../../core/utils/error_utils.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
        .listen((data) async {
      final Session? session = data.session;
      if (session != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          final userId = session.user.id;
          bool hasRole = false;
          
          try {
            final roleResponse = await SupabaseService.instance.client
                .from('user_roles')
                .select('id')
                .eq('user_id', userId)
                .maybeSingle();
            hasRole = roleResponse != null;
          } catch (_) {}

          await _applyScreenSecurity();
          
          if (mounted) {
            if (!hasRole) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            } else {
              // Check if profile exists
              final dbService = DatabaseService.instance;
              final role = await dbService.getUserRole();
              
              if (role == 'student') {
                final profile = await dbService.getStudentProfile(userId);
                if (profile == null) {
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  }
                  return;
                }
              }

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              }
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glassmorphism Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo and Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'منصة دوراتي',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.withOpacity(0.3),
                                        Colors.blue.withOpacity(0.3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 32,
                                    height: 32,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),

                            // Welcome Text
                            const Text(
                              'مرحباً بك',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Email Field
                            _buildGlassTextField(
                              controller: _emailController,
                              hint: 'البريد الإلكتروني',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 20),

                            // Password Field
                            _buildGlassTextField(
                              controller: _passwordController,
                              hint: 'كلمة المرور',
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),

                            const SizedBox(height: 30),

                            // Login Button
                            _buildLoginButton(),

                            const SizedBox(height: 20),

                            // Forgot Password
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Divider with "أو"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'أو',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // Social Login Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                  icon: Icons.g_mobiledata,
                                  onTap: _handleGoogleLogin,
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // Sign Up Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'ليس لديك حساب؟',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'سجل الآن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final textColor = AppColors.getTextColor(context);
    final secondaryTextColor = AppColors.getTextColor(context, secondary: true);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType: keyboardType,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
              prefixIcon: Icon(
                icon,
                color: secondaryTextColor,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: secondaryTextColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.lightPurple,
            AppColors.indigoBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightPurple.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _isLoading ? null : _handleLogin,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('الرجاء إدخال البريد الإلكتروني');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال كلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // Apply screen security based on user role
        await _applyScreenSecurity();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(_getErrorMessage(e));
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    bool isDialogLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: AppColors.getSurfaceColor(context),
              title: Text(
                'استعادة كلمة المرور',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
                textAlign: TextAlign.right,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'البريد الإلكتروني',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.getTextColor(context, secondary: true),
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.getTextColor(context, secondary: true),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.getTextColor(context, secondary: true).withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: AppColors.primaryPurple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                  ),
                ),
                isDialogLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'الرجاء إدخال البريد الإلكتروني',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            isDialogLoading = true;
                          });
                          try {
                            await AuthService().resetPassword(email);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني.',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isDialogLoading = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _getErrorMessage(e),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  backgroundColor: Colors.red.shade400,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'إرسال',
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.signInWithGoogle();

      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // لهذه المنصات، ننتظر مستمع AuthState في initState ليقوم بالتحويل عند اكتشاف الجلسة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جاري التحقق من الحساب...',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Apply screen security based on user role
        await _applyScreenSecurity();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (e.toString() != 'تم إلغاء تسجيل الدخول عبر جوجل') {
          _showErrorSnackBar(_getErrorMessage(e));
        }
      }
    }
  }

  String _getErrorMessage(Object error) {
    return ErrorUtils.getFriendlyErrorMessage(error);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
