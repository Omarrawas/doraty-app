import 'package:go_router/go_router.dart';
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
import '../../core/utils/error_utils.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';

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

  String _t(String key) {
    if (!mounted) return key;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

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
              context.go('/register');
            } else {
              // Check if profile exists
              final dbService = DatabaseService.instance;
              final role = await dbService.getUserRole();
              
              if (role == 'student') {
                final profile = await dbService.getStudentProfile(userId);
                if (profile == null) {
                  if (mounted) {
                    context.go('/register');
                  }
                  return;
                }
              }

              if (mounted) {
                context.go('/');
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
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glassmorphism Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: AppColors.getGlassColor(context, opacity: 0.25),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: AppColors.getBorderColor(context),
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
                                Text(
                                  _t('platform_name'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Container(
                                  padding: EdgeInsets.all(12),
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

                            SizedBox(height: 40),

                            // Welcome Text
                            Text(
                              _t('welcome_text'),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),

                            SizedBox(height: 40),

                            // Email Field
                            _buildGlassTextField(
                              controller: _emailController,
                              hint: _t('email_label'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            SizedBox(height: 20),

                            // Password Field
                            _buildGlassTextField(
                              controller: _passwordController,
                              hint: _t('password_label'),
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),

                            SizedBox(height: 30),

                            // Login Button
                            _buildLoginButton(),

                            SizedBox(height: 20),

                            // Forgot Password
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(
                                _t('forgot_password'),
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Divider with "أو"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.getMutedTextColor(context),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _t('or'),
                                    style: TextStyle(
                                      color: AppColors.getTextColor(context),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.getMutedTextColor(context),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 30),

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

                            SizedBox(height: 30),

                            // Sign Up Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _t('dont_have_account'),
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context),
                                    fontSize: 15,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push('/register');
                                  },
                                  child: Text(
                                    _t('register_now'),
                                    style: TextStyle(
                                      color: AppColors.getTextColor(context),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 10),

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
              color: AppColors.getMutedTextColor(context),
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
              contentPadding: EdgeInsets.symmetric(
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
        gradient: LinearGradient(
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
            offset: Offset(0, 10),
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
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.getTextColor(context),
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _t('login_title'),
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
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
      _showErrorSnackBar(_t('error_enter_email'));
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar(_t('error_enter_password'));
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
                _t('reset_password'),
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
                    _t('reset_password_desc'),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: _t('email_label'),
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
                        borderSide: BorderSide(
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
                  child: Text(
                    _t('cancel'),
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                  ),
                ),
                isDialogLoading
                    ? Padding(
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
                                content: Text(
                                  _t('error_enter_email'),
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
                                SnackBar(
                                  content: Text(
                                    _t('reset_password_success'),
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
                                    style: TextStyle(fontFamily: 'Cairo'),
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
                        child: Text(
                          _t('send'),
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.getTextColor(context)),
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
            SnackBar(
              content: Text(_t('checking_account'),
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
        if (e.toString() != _t('login_canceled')) {
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
          style: TextStyle(fontFamily: 'Cairo'),
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
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getBorderColor(context),
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
                color: AppColors.getTextColor(context),
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
