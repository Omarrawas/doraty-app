import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/category_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/routing/routes_names.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeDrawer extends StatefulWidget {
  final List<CategoryModel> categories;

  const HomeDrawer({
    super.key,
    required this.categories,
  });

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  Future<Map<String, String>>? _socialLinksFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future so it doesn't keep refreshing on every build
    _socialLinksFuture = DatabaseService().getSocialLinks();
  }

  String _t(BuildContext context, String key) {
    return AppStrings.get(
      key,
      Provider.of<LocaleProvider>(context, listen: false).locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final localeProvider = Provider.of<LocaleProvider>(context);
        final userProfile = authService.userProfile;
        final isDark = themeProvider.isDarkMode;
        final isAuthenticated = authService.isAuthenticated;

        final screenWidth = MediaQuery.of(context).size.width;

        return Drawer(
          width: screenWidth > 438 ? 350 : screenWidth * 0.8,
          backgroundColor: AppColors.getDrawerBackground(context),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
              bottomEnd: Radius.circular(40),
              topEnd: Radius.circular(0),
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(context, userProfile, isDark, isAuthenticated),

              // Content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: Icons.home_outlined,
                      title: _t(context, 'home'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),

                    // Dashboard for Admin/Teacher
                    if (authService.userRole == 'admin' ||
                        authService.userRole == 'super_admin' ||
                        authService.userRole == 'teacher')
                      _buildDrawerItem(
                        context,
                        icon: Icons.dashboard_outlined,
                        title: (authService.userRole == 'teacher')
                            ? _t(context, 'teacher_dashboard')
                            : _t(context, 'admin_dashboard'),
                        onTap: () {
                          Navigator.pop(context);
                          if (authService.userRole == 'teacher') {
                            context.push('/teacher_dashboard');
                          } else {
                            context.push('/admin');
                          }
                        },
                      ),

                    // Categories ExpansionTile
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Icon(Icons.category_outlined,
                            color: isDark ? Colors.white70 : Colors.black87),
                        title: Text(
                          _t(context, 'categories'),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        children: widget.categories
                            .map((cat) => ListTile(
                                  contentPadding:
                                      const EdgeInsetsDirectional.only(
                                          start: 72),
                                  title: Text(cat.name,
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontSize: 14)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.go('/courses?categoryId=${cat.id}');
                                  },
                                ))
                            .toList(),
                      ),
                    ),

                    // Protected User Sections
                    if (authService.isAuthenticated) ...[
                      _buildDrawerItem(
                        context,
                        icon: Icons.library_books_outlined,
                        title: _t(context, 'my_courses'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my_courses');
                        },
                      ),
                      _buildDrawerItem(
                        context,
                        icon: Icons.receipt_long_outlined,
                        title: _t(context, 'my_receipts'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push(AppRoutes.orders);
                        },
                      ),
                    ],

                    _buildDrawerItem(
                      context,
                      icon: Icons.people_outline,
                      title: _t(context, 'top_teachers'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/teachers');
                      },
                    ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.card_giftcard_outlined,
                      title: _t(context, 'all_bundles'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/packages');
                      },
                    ),

                    if (authService.isAuthenticated)
                      _buildDrawerItem(
                        context,
                        icon: Icons.favorite_border,
                        title: _t(context, 'favorites'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/favorites');
                        },
                      ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.lightbulb_outline,
                      title: _t(context, 'learning_tips_title'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/tips');
                      },
                    ),

                    Divider(
                        color: AppColors.getMutedTextColor(context)
                            .withOpacity(0.1)),

                    if (authService.isAuthenticated)
                      _buildDrawerItem(
                        context,
                        icon: Icons.settings_outlined,
                        title: _t(context, 'settings'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/settings');
                        },
                      ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.contact_support_outlined,
                      title: _t(context, 'contact_support'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSupportDialog(context);
                      },
                    ),

                    // Language Toggle
                    _buildDrawerItem(
                      context,
                      icon: Icons.language_outlined,
                      title: _t(context, 'language'),
                      trailing: Text(
                          localeProvider.locale == 'ar' ? 'English' : 'العربية',
                          style: TextStyle(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold)),
                      onTap: () {
                        localeProvider.setLocale(
                            localeProvider.locale == 'ar' ? 'en' : 'ar');
                      },
                    ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.quiz_outlined,
                      title: _t(context, 'faq'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.faq);
                      },
                    ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: _t(context, 'privacy_policy'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.privacy);
                      },
                    ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.description_outlined,
                      title: _t(context, 'terms_conditions'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.terms);
                      },
                    ),

                    // Theme Toggle
                    SwitchListTile(
                      secondary: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: isDark ? Colors.white70 : Colors.black87),
                      title: Text(
                        _t(context, 'dark_mode_title'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: isDark,
                      onChanged: (val) {
                        themeProvider.toggleTheme();
                      },
                      activeColor: AppColors.primaryPurple,
                    ),

                    const SizedBox(height: 20),

                    // Social Media Icons
                    FutureBuilder<Map<String, String>>(
                      future: _socialLinksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final links = snapshot.data!;
                        final isDarkInner =
                            Provider.of<ThemeProvider>(context).isDarkMode;

                        final List<Widget> availablePlatforms = [];

                        if (links['social_facebook']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.facebook),
                              Colors.blue,
                              links['social_facebook']!));
                        }
                        if (links['social_instagram']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.instagram),
                              Colors.pink,
                              links['social_instagram']!));
                        }
                        if (links['social_youtube']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.youtube),
                              Colors.red,
                              links['social_youtube']!));
                        }
                        if (links['social_whatsapp']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.whatsapp), Colors.green, links['social_whatsapp']!));
                        }
                        if (links['social_x_twitter']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.xTwitter),
                              isDarkInner ? Colors.white : Colors.black87,
                              links['social_x_twitter']!));
                        }
                        if (links['social_tiktok']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.tiktok),
                              isDarkInner ? Colors.white : Colors.black87,
                              links['social_tiktok']!));
                        }
                        if (links['social_telegram']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.telegram),
                              Colors.blueAccent,
                              links['social_telegram']!));
                        }
                        if (links['social_linkedin']?.isNotEmpty == true) {
                          availablePlatforms.add(_buildSocialIcon(
                              const FaIcon(FontAwesomeIcons.linkedin),
                              Colors.blue[800] ?? Colors.blue,
                              links['social_linkedin']!));
                        }

                        if (availablePlatforms.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 20,
                            runSpacing: 15,
                            children: availablePlatforms,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Logout or Login
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: authService.isAuthenticated
                          ? ElevatedButton.icon(
                              onPressed: () => authService.signOut(),
                              icon: const Icon(Icons.logout),
                              label: Text(_t(context, 'logout')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push('/login');
                              },
                              icon: const Icon(Icons.login),
                              label: const Text(
                                  'تسجيل الدخول / إنشاء حساب'), // explicit text
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple
                                    .withOpacity(0.1),
                                foregroundColor: AppColors.primaryPurple,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? profile,
      bool isDark, bool isAuthenticated) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    String? userName = profile?['full_name'] ?? profile?['name'];
    if (userName == null && currentUser != null) {
      userName = currentUser.userMetadata?['full_name'] ??
          currentUser.userMetadata?['name'] ??
          currentUser.email?.split('@').first;
    }

    final photoUrl = profile?['avatar_url'] ??
        profile?['photo_url'] ??
        currentUser?.userMetadata?['avatar_url'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 10, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryPurple,
            AppColors.primaryPurple.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person,
                        size: 35, color: AppColors.primaryPurple)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuthenticated
                          ? '${_t(context, 'welcome_with_name')} ${userName ?? ''} 👋'
                          : '${_t(context, 'welcome')} 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _t(context, 'ready_to_learn'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSocialIcon(Widget iconWidget, Color color, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: IconTheme(
          data: IconThemeData(color: color, size: 28),
          child: iconWidget,
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(context, 'support_dialog_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t(context, 'support_dialog_desc')),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.primaryPurple),
              title: Text(_t(context, 'email_us')),
              onTap: () {
                // Email logic
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
              title: Text(_t(context, 'whatsapp_us')),
              onTap: () {
                // WhatsApp logic
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t(context, 'close')),
          ),
        ],
      ),
    );
  }
}
