import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/category_model.dart';
import '../../explore/explore_screen.dart';
import '../../courses/courses_list_screen.dart';
import '../../downloads/downloads_screen.dart';
import '../../tips/all_tips_screen.dart';
import '../../settings/settings_screen.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../teacher/teacher_dashboard_screen.dart';
import '../../profile/order_history_screen.dart';

class HomeDrawer extends StatelessWidget {
  final List<CategoryModel> categories;

  const HomeDrawer({
    super.key,
    required this.categories,
  });

  String _t(BuildContext context, String key) {
    return AppStrings.get(
      key,
      Provider.of<LocaleProvider>(context, listen: false).locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final userProfile = authService.userProfile;
    final isDark = themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: Column(
        children: [
          // Header
          _buildHeader(context, userProfile, isDark),

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
                    // Already on Home
                  },
                ),

                // Dashboard for Admin/Teacher
                if (userProfile?['role'] == 'admin' || 
                    userProfile?['role'] == 'super_admin' || 
                    userProfile?['role'] == 'teacher' ||
                    userProfile?['is_admin'] == true)
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    title: (userProfile?['role'] == 'teacher') 
                        ? 'لوحة تحكم المعلم' 
                        : 'لوحة تحكم الأدمن',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => (userProfile?['role'] == 'teacher') 
                               ? const TeacherDashboardScreen() 
                               : const AdminDashboardScreen(),
                        ),
                      );
                    },
                  ),
                
                // Categories ExpansionTile
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(Icons.category_outlined, 
                      color: isDark ? Colors.white70 : Colors.black87),
                    title: Text(_t(context, 'categories'),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: categories.map((cat) => ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(start: 72),
                      title: Text(cat.name, 
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()));
                        // Note: In a real app, we'd pass the category ID to ExploreScreen
                      },
                    )).toList(),
                  ),
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.library_books_outlined,
                  title: 'دوراتي',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesListScreen(showBackButton: true)));
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.offline_pin_outlined,
                  title: 'تنزيلاتي',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'إيصالاتي',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.favorite_border,
                  title: 'المفضلة', // Placeholder
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.lightbulb_outline,
                  title: 'نصائح',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AllTipsScreen()));
                  },
                ),

                const Divider(color: Colors.white10),

                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: _t(context, 'settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
                  trailing: Text(localeProvider.locale == 'ar' ? 'English' : 'العربية',
                    style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                  onTap: () {
                    localeProvider.setLocale(localeProvider.locale == 'ar' ? 'en' : 'ar');
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.question_answer_outlined,
                  title: 'الأسئلة الشائعة',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.description_outlined,
                  title: _t(context, 'terms_conditions'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                // Theme Toggle
                SwitchListTile(
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.white70 : Colors.black87),
                  title: Text('الوضع الليلي', // Dark Mode
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialIcon(Icons.facebook, Colors.blue),
                      _buildSocialIcon(Icons.camera_alt, Colors.pink), // Instagram placeholder
                      _buildSocialIcon(Icons.play_circle_filled, Colors.red), // YouTube placeholder
                      _buildSocialIcon(Icons.message, Colors.lightBlue), // Twitter/X or Telegram
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Logout
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
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
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? profile, bool isDark) {
    final name = profile?['full_name'] ?? 'Guest User';
    final email = profile?['email'] ?? 'guest@doraty.com';
    final photoUrl = profile?['photo_url'] ?? profile?['avatar_url'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 35, color: AppColors.primaryPurple) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
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
              leading: const Icon(Icons.chat, color: Colors.green),
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
