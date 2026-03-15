import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart' as theme_provider;
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/database_service.dart';
import '../auth/login_screen.dart';
import '../../core/services/offline_storage_service.dart';
import 'dart:ui' as ui;
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import '../../core/constants/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/utils/error_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String _appVersion = '';
  String? _userRole;
  Map<String, dynamic>? _specializedProfile;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  void _loadSettings() {
    final settings = SettingsService();
    setState(() {
      _notificationsEnabled = settings.getNotificationsEnabled();
      _autoDownload = settings.getAutoDownload();
      _wifiOnly = settings.getWifiOnly();
    });
  }

  String get _selectedLanguage =>
      Provider.of<LocaleProvider>(context, listen: false).locale;

  Future<void> _loadUserProfile() async {
    try {
      final authService = AuthService();
      final dbService = DatabaseService.instance;
      
      final profile = await authService.getUserProfile();
      if (profile != null) {
        final role = await dbService.getUserRole();
        Map<String, dynamic>? specialized;
        
        if (role == 'student') {
          specialized = await dbService.getStudentProfile(profile['id']);
        } else if (role == 'teacher') {
          specialized = await dbService.getTeacherProfile(profile['id']);
        }

        setState(() {
          _userProfile = profile;
          _currentAvatarUrl = profile['avatar_url'];
          _userRole = role;
          _specializedProfile = specialized;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
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
          SnackBar(content: Text(_t('changes_saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _updateSpecializedProfile(Map<String, dynamic> updates) async {
    try {
      final userId = _userProfile?['id'];
      if (userId == null) return;

      final dbService = DatabaseService.instance;
      if (_userRole == 'student') {
        await dbService.updateStudentProfile(userId, updates);
      } else if (_userRole == 'teacher') {
        await dbService.updateTeacherProfile(userId, updates);
      }

      await _loadUserProfile(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('changes_saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<theme_provider.ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final selectedLanguage = localeProvider.locale;

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
                    _buildSectionTitle(_t('profile')),
                    const SizedBox(height: 12),
                    _buildProfileAvatar(),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.person,
                      title: _t('name'),
                      subtitle: _userProfile?['full_name'] ?? _t('profile'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: _showNameEditDialog,
                    ),

                    if (_userRole == 'student') ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(_t('educational_info')),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.school_outlined,
                        title: _t('education_level'),
                        subtitle: _specializedProfile?['education_level'] == 'school' ? 'مدرسة' : 'جامعة',
                        onTap: () => _showEducationLevelDialog(),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.grade_outlined,
                        title: _t('grade'),
                        subtitle: _specializedProfile?['grade'] ?? 'غير محدد',
                        onTap: () => _showGradeDialog(),
                      ),
                      if (_specializedProfile?['education_level'] == 'university') ...[
                        const SizedBox(height: 12),
                        _buildSettingCard(
                          icon: Icons.workspace_premium_outlined,
                          title: _t('specialization'),
                          subtitle: _specializedProfile?['specialization'] ?? 'غير محدد',
                          onTap: () => _showSpecializationDialog(),
                        ),
                      ],
                    ] else if (_userRole == 'teacher') ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(_t('professional_info')),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.workspace_premium_outlined,
                        title: _t('specialization'),
                        subtitle: _specializedProfile?['specialization'] ?? 'غير محدد',
                        onTap: () => _showSpecializationDialog(),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.public_rounded,
                        title: _t('country'),
                        subtitle: _specializedProfile?['country'] ?? 'غير محدد',
                        onTap: () => _showCountryDialog(),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.phone_android,
                        title: _t('phone_number'),
                        subtitle: _specializedProfile?['phone_number'] ?? _t('not_specified'),
                        onTap: () => _showPhoneDialog(),
                      ),
                      const SizedBox(height: 12),
                       _buildSettingCard(
                        icon: Icons.upload_file_rounded,
                        title: 'السيرة الذاتية (CV)',
                        subtitle: _specializedProfile?['cv_url'] != null ? 'تم رفع ملف' : 'لم يتم الرفع',
                        onTap: _pickCV,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.workspace_premium_rounded,
                        title: 'الشهادات العلمية',
                        subtitle: _specializedProfile?['certificates_url'] != null ? 'تم رفع الملف' : 'لم يتم الرفع',
                        onTap: _pickCertificates,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        icon: Icons.description_outlined,
                        title: _t('bio'),
                        subtitle: _specializedProfile?['bio'] ?? 'لا يوجد نبذة',
                        onTap: () => _showBioDialog(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Theme Section
                    _buildSectionTitle(_t('theme')),
                    const SizedBox(height: 12),
                    _buildThemeSelector(themeProvider),

                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildSectionTitle(_t('notifications')),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.notifications,
                      title: _t('enable_notifications'),
                      subtitle: _t('notifications_desc'),
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
                    _buildSectionTitle(_t('downloads')),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.download,
                      title: _t('auto_download'),
                      subtitle: _t('auto_download_desc'),
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
                      title: _t('wifi_only'),
                      subtitle: _t('wifi_only_desc'),
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
                      title: _t('video_quality'),
                      subtitle: _videoQuality == 'عالية'
                          ? _t('video_quality_high')
                          : (_videoQuality == 'متوسطة'
                              ? _t('video_quality_medium')
                              : _t('video_quality_low')),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: () => _showQualityDialog(),
                    ),

                    const SizedBox(height: 12),

                    _buildSettingCard(
                      icon: Icons.delete_outline,
                      title: _t('clear_downloads'),
                      subtitle: _t('clear_downloads_desc'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: _clearAllDownloads,
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    _buildSectionTitle(_t('about')),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.info_outline,
                      title: _t('version'),
                      subtitle: _appVersion.isNotEmpty ? _appVersion : '...',
                    ),

                    _buildSettingCard(
                      icon: Icons.privacy_tip_outlined,
                      title: _t('privacy_policy'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
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
                      title: _t('terms_conditions'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
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

                    // Support & Safety Section
                    _buildSectionTitle(_t('contact_support')),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.headset_mic_outlined,
                      title: _t('contact_support'),
                      subtitle: _t('support_desc'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: _showSupportDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.person_remove_outlined,
                      title: _t('delete_account'),
                      subtitle: _t('delete_account_desc'),
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: _showDeleteAccountDialog,
                    ),

                    const SizedBox(height: 24),

                    // Language Section
                    _buildSectionTitle(_t('language')),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.language,
                      title: _t('app_language'),
                      subtitle:
                          selectedLanguage == 'ar' ? 'العربية' : 'English',
                      trailing: Icon(
                        selectedLanguage == 'ar'
                            ? Icons.chevron_left
                            : Icons.chevron_right,
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
          Expanded(
            child: Text(
              _t('settings'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
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
                    Expanded(
                      child: Text(
                        _t('change_photo'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    Icon(
                      _selectedLanguage == 'ar'
                          ? Icons.chevron_left
                          : Icons.chevron_right,
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
        fontFamily: 'Cairo',
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
                  Expanded(
                    child: Text(
                      _t('display_mode'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
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
                      label: _t('light'),
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
                      label: _t('dark'),
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
                      label: _t('system'),
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
                fontFamily: 'Cairo',
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
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                  fontFamily: 'Cairo',
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
                    backgroundColor: AppColors.getSurfaceColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      _t('logout_confirm_title'),
                      textAlign: _selectedLanguage == 'ar'
                          ? TextAlign.right
                          : TextAlign.left,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      _t('logout_confirm_desc'),
                      textAlign: _selectedLanguage == 'ar'
                          ? TextAlign.right
                          : TextAlign.left,
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          _t('cancel'),
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text(
                          _t('logout'),
                          style: const TextStyle(
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
                          content: Text('${_t('error_logout')}: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _t('logout'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontFamily: 'Cairo',
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
                  Text(
                    _t('choose_photo'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: _t('camera'),
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: _t('gallery'),
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
                    fontFamily: 'Cairo',
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
          SnackBar(content: Text('${_t('error_image_pick')}: $e')),
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
          SnackBar(content: Text('${_t('error_image_upload')}: $e')),
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
                  Text(
                    _t('edit_name'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    textAlign: _selectedLanguage == 'ar'
                        ? TextAlign.right
                        : TextAlign.left,
                    decoration: InputDecoration(
                      hintText: _t('enter_full_name'),
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
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            _t('cancel'),
                            style: const TextStyle(
                                color: Colors.white70, fontFamily: 'Cairo'),
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
                          child: Text(_t('save')),
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
                  Text(
                    _t('video_quality'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...['عالية', 'متوسطة', 'منخفضة'].map((quality) {
                    final label = quality == 'عالية'
                        ? _t('video_quality_high')
                        : (quality == 'متوسطة'
                            ? _t('video_quality_medium')
                            : _t('video_quality_low'));
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
                                    label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontFamily: 'Cairo',
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
                  Text(
                    _t('language'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
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
        onTap: () {
          context.read<LocaleProvider>().setLocale(code);
          Navigator.pop(context);
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
                  style: const TextStyle(
                      fontSize: 16, color: Colors.white, fontFamily: 'Cairo'),
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
        backgroundColor: AppColors.getSurfaceColor(context),
        title: Text(_t('clear_downloads_confirm_title')),
        content: Text(_t('clear_downloads_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _t('clear'),
              style: const TextStyle(color: Colors.red, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator or snackbar before deleting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('clearing'))),
        );
      }

      await OfflineStorageService().clearAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('clear_success'))),
        );
        // Refresh settings or stats if needed
      }
    }
  }

  void _showSupportDialog() {
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
                  Text(
                    _t('support_dialog_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('support_dialog_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 24),
                  _buildSupportOption(
                    icon: Icons.email_outlined,
                    label: _t('email_us'),
                    onTap: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'support@doraty.com',
                        query: Uri.encodeFull(
                            'subject=Support Request from ${_userProfile?['full_name']}'),
                      );
                      if (await canLaunchUrl(emailLaunchUri)) {
                        await launchUrl(emailLaunchUri);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSupportOption(
                    icon: Icons.chat_outlined,
                    label: _t('whatsapp_us'),
                    onTap: () async {
                      final whatsappUrl = Uri.parse(
                          "https://wa.me/+963931865704"); // Placeholder
                      if (await canLaunchUrl(whatsappUrl)) {
                        await launchUrl(whatsappUrl,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        title: Text(
          _t('delete_confirm_title'),
          style:
              const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo'),
        ),
        content: Text(_t('delete_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              _t('delete'),
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await AuthService().deleteAccount();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  final List<String> _schoolGrades = [
    'الصف الأول', 'الصف الثاني', 'الصف الثالث',
    'الصف الرابع', 'الصف الخامس', 'الصف السادس',
    'الصف السابع', 'الصف الثامن', 'الصف التاسع',
    'الصف العاشر', 'الحادي عشر', 'البكالوريا'
  ];

  final List<String> _universityYears = [
    'السنة الأولى', 'السنة الثانية', 'السنة الثالثة',
    'السنة الرابعة', 'السنة الخامسة', 'السنة السادسة',
    'خريج'
  ];

  void _showEducationLevelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('education_level')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('مدرسة'),
              onTap: () {
                _updateSpecializedProfile({
                  'education_level': 'school',
                  'grade': _schoolGrades.first,
                  'specialization': null
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('جامعة'),
              onTap: () {
                _updateSpecializedProfile({
                  'education_level': 'university',
                  'grade': _universityYears.first
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGradeDialog() {
    final isSchool = _specializedProfile?['education_level'] == 'school';
    final items = isSchool ? _schoolGrades : _universityYears;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('grade')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(items[index]),
              onTap: () {
                _updateSpecializedProfile({'grade': items[index]});
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showSpecializationDialog() {
    final controller =
        TextEditingController(text: _specializedProfile?['specialization']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('specialization')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: _t('specialization')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () {
              _updateSpecializedProfile(
                  {'specialization': controller.text.trim()});
              Navigator.pop(context);
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }

  void _showCountryDialog() {
    final controller =
        TextEditingController(text: _specializedProfile?['country']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('country')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: _t('country')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () {
              _updateSpecializedProfile({'country': controller.text.trim()});
              Navigator.pop(context);
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }

  void _showBioDialog() {
    final controller = TextEditingController(text: _specializedProfile?['bio']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('bio')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: _t('bio')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () {
              _updateSpecializedProfile({'bio': controller.text.trim()});
              Navigator.pop(context);
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }

  void _showPhoneDialog() {
    final controller =
        TextEditingController(text: _specializedProfile?['phone_number']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('phone_number')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: _t('phone_number')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () {
              _updateSpecializedProfile({'phone_number': controller.text.trim()});
              Navigator.pop(context);
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _uploadCV(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    }
  }

  Future<void> _uploadCV(File file) async {
    try {
      final userId = _userProfile?['id'];
      if (userId == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري رفع السيرة الذاتية...')),
        );
      }

      final storageService = StorageService();
      final cvUrl = await storageService.uploadTeacherDocument(file, userId, 'cv');

      await _updateSpecializedProfile({'cv_url': cvUrl});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الملف: $e')),
        );
      }
    }
  }

  Future<void> _pickCertificates() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _uploadCertificates(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    }
  }

  Future<void> _uploadCertificates(File file) async {
    try {
      final userId = _userProfile?['id'];
      if (userId == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري رفع الشهادات...')),
        );
      }

      final storageService = StorageService();
      final certificateUrl = await storageService.uploadTeacherDocument(file, userId, 'certificates');

      await _updateSpecializedProfile({'certificates_url': certificateUrl});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الملف: $e')),
        );
      }
    }
  }
}
