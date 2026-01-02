import 'package:flutter/material.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart' as theme_provider;
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/settings_service.dart';
import '../../models/category.dart';
import '../auth/login_screen.dart';
import '../categories/branch_selection_screen.dart';
import '../../core/services/offline_storage_service.dart';
import 'dart:ui' as ui;
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoDownload = false;
  bool _wifiOnly = true;
  String _videoQuality = 'عالية';

  // User profile data
  Map<String, dynamic>? _userProfile;
  String? _currentAvatarUrl;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  void _loadSettings() {
    final settings = SettingsService();
    setState(() {
      _notificationsEnabled = settings.getNotificationsEnabled();
      _autoDownload = settings.getAutoDownload();
      _wifiOnly = settings.getWifiOnly();
      _videoQuality = settings.getVideoQuality();
      _selectedLanguage = settings.getLanguage();
    });
  }

  String _selectedLanguage = 'ar';

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService().getUserProfile();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _currentAvatarUrl = profile['avatar_url'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  Future<void> _updateUserProfile(Map<String, dynamic> updates) async {
    try {
      await AuthService().updateUserProfile(updates);
      await _loadUserProfile(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التغييرات')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ التغييرات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<theme_provider.ThemeProvider>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeProvider.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Profile Section
                    _buildSectionTitle('الملف الشخصي'),
                    const SizedBox(height: 12),
                    _buildProfileAvatar(),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.person,
                      title: 'الاسم',
                      subtitle: _userProfile?['full_name'] ?? 'المستخدم',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: _showNameEditDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.school,
                      title: 'الفرع الدراسي',
                      subtitle: _userProfile?['branch'] ?? 'غير محدد',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: _showBranchSelection,
                    ),

                    const SizedBox(height: 24),

                    // Theme Section
                    _buildSectionTitle('المظهر'),
                    const SizedBox(height: 12),
                    _buildThemeSelector(themeProvider),

                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildSectionTitle('الإشعارات'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.notifications,
                      title: 'تفعيل الإشعارات',
                      subtitle: 'استقبال إشعارات الدروس والاختبارات',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          await SettingsService().setNotificationsEnabled(value);
                        },
                        activeColor: AppColors.primaryPurple,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Download Section
                    _buildSectionTitle('التحميل'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.download,
                      title: 'التحميل التلقائي',
                      subtitle: 'تحميل الدروس تلقائياً عند الاتصال بالواي فاي',
                      trailing: Switch(
                        value: _autoDownload,
                        onChanged: (value) async {
                          setState(() {
                            _autoDownload = value;
                          });
                          await SettingsService().setAutoDownload(value);
                        },
                        activeColor: AppColors.primaryPurple,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildSettingCard(
                      icon: Icons.wifi,
                      title: 'التحميل عبر واي فاي فقط',
                      subtitle: 'توفير استهلاك البيانات عبر شبكة الجوال',
                      trailing: Switch(
                        value: _wifiOnly,
                        onChanged: (value) async {
                          setState(() {
                            _wifiOnly = value;
                          });
                          await SettingsService().setWifiOnly(value);
                        },
                        activeColor: AppColors.primaryPurple,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildSettingCard(
                      icon: Icons.high_quality,
                      title: 'جودة الفيديو',
                      subtitle: _videoQuality,
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: () => _showQualityDialog(),
                    ),

                    const SizedBox(height: 12),

                    _buildSettingCard(
                      icon: Icons.delete_outline,
                      title: 'مسح التنزيلات',
                      subtitle: 'حذف جميع الدروس المحملة لتوفير المساحة',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: _clearAllDownloads,
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    _buildSectionTitle('حول التطبيق'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.info_outline,
                      title: 'الإصدار',
                      subtitle: '1.0.0',
                    ),

                    _buildSettingCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'سياسة الخصوصية',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                        );
                      },
                    ),

                    _buildSettingCard(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TermsConditionsScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Language Section
                    _buildSectionTitle('اللغة'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.language,
                      title: 'لغة التطبيق',
                      subtitle: _selectedLanguage == 'ar' ? 'العربية' : 'English',
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                      onTap: _showLanguageDialog,
                    ),

                    const SizedBox(height: 24),

                    // Logout Button
                    _buildLogoutButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'الإعدادات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showImageSourceDialog,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.white70,
                                    ),
                                  )
                                : (_currentAvatarUrl != null &&
                                        _currentAvatarUrl!.isNotEmpty)
                                    ? Image.network(
                                        _currentAvatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          final userName =
                                              _userProfile?['full_name']
                                                      ?.trim() ??
                                                  'User';
                                          final fallbackUrl =
                                              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=7B2CBF&color=fff&size=200';
                                          return Image.network(
                                            fallbackUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.person,
                                              size: 30,
                                              color: Colors.white70,
                                            ),
                                          );
                                        },
                                      )
                                    : Builder(
                                        builder: (context) {
                                          final userName =
                                              _userProfile?['full_name']
                                                      ?.trim() ??
                                                  'User';
                                          final avatarUrl =
                                              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=7B2CBF&color=fff&size=200';
                                          return Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.person,
                                              size: 30,
                                              color: Colors.white70,
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: Color(0xFF7B2CBF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'تغيير الصورة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildThemeSelector(theme_provider.ThemeProvider themeProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'وضع العرض',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeOption(
                      icon: Icons.light_mode,
                      label: 'فاتح',
                      isSelected: themeProvider.appThemeMode ==
                          theme_provider.AppThemeMode.light,
                      onTap: () => themeProvider
                          .setThemeMode(theme_provider.AppThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      icon: Icons.dark_mode,
                      label: 'داكن',
                      isSelected: themeProvider.appThemeMode ==
                          theme_provider.AppThemeMode.dark,
                      onTap: () => themeProvider
                          .setThemeMode(theme_provider.AppThemeMode.dark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      icon: Icons.brightness_auto,
                      label: 'تلقائي',
                      isSelected: themeProvider.appThemeMode ==
                          theme_provider.AppThemeMode.system,
                      onTap: () => themeProvider
                          .setThemeMode(theme_provider.AppThemeMode.system),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected
              ? null
              : AppColors.getGlassColor(context, opacity: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.getGlassColor(context, opacity: 0.5)
                : AppColors.getGlassColor(context, opacity: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.getGlassColor(context, opacity: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white.withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'تسجيل الخروج',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      'هل أنت متأكد من تسجيل الخروج؟',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true && mounted) {
                  try {
                    await AuthService().signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('خطأ في تسجيل الخروج: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختيار الصورة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'الكاميرا',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'معرض الصور',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        await _uploadAvatar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصورة: $e')),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;

    try {
      final storageService = StorageService();
      final avatarUrl = await storageService.uploadAvatar(_selectedImage!);

      // Add cache busting to the uploaded URL to force refresh
      final cacheBustedUrl = storageService.addCacheBusting(avatarUrl);

      await _updateUserProfile({'avatar_url': cacheBustedUrl});
      setState(() {
        _currentAvatarUrl = cacheBustedUrl;
        _selectedImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الصورة: $e')),
        );
      }
    }
  }

  void _showNameEditDialog() {
    final nameController =
        TextEditingController(text: _userProfile?['full_name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعديل الاسم',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'أدخل الاسم الكامل',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF7B2CBF), width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final newName = nameController.text.trim();
                            if (newName.isNotEmpty) {
                              await _updateUserProfile({'full_name': newName});
                              if (mounted) {
                                navigator.pop();
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B2CBF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBranchSelection() async {
    final selectedBranch = await Navigator.push<Branch>(
      context,
      MaterialPageRoute(
        builder: (context) => const BranchSelectionScreen(fromSettings: true),
      ),
    );

    if (selectedBranch != null) {
      await _updateUserProfile({'branch': selectedBranch.name});
      // Reload user profile data to refresh the UI
      await _loadUserProfile();
    }
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'جودة الفيديو',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...['عالية', 'متوسطة', 'منخفضة'].map((quality) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            await _updateVideoQuality(quality);
                            if (mounted) navigator.pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _videoQuality == quality
                                  ? AppColors.primaryPurple.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _videoQuality == quality
                                    ? AppColors.primaryPurple
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    quality,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (_videoQuality == quality)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryPurple,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر اللغة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLanguageOption('ar', 'العربية'),
                  const SizedBox(height: 12),
                  _buildLanguageOption('en', 'English'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String code, String label) {
    bool isSelected = _selectedLanguage == code;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          setState(() {
            _selectedLanguage = code;
          });
          await SettingsService().setLanguage(code);
          if (mounted) Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryPurple.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryPurple : Colors.white.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primaryPurple),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateVideoQuality(String quality) async {
    setState(() {
      _videoQuality = quality;
    });
    await SettingsService().setVideoQuality(quality);
  }

  Future<void> _clearAllDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('مسح التنزيلات'),
        content: const Text('هل أنت متأكد من مسح جميع الدروس المحملة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'مسح',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator or snackbar before deleting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري مسح التنزيلات...')),
        );
      }

      await OfflineStorageService().clearAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح جميع التنزيلات بنجاح')),
        );
        // Refresh settings or stats if needed
      }
    }
  }
}
