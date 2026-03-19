import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart' as theme_provider;
import '../../core/services/auth_service.dart';
import '../../core/services/settings_service.dart';
import '../auth/login_screen.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import '../../core/constants/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/locale_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' as ui;
import '../../core/services/offline_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  bool _notificationsEnabled = true;
  bool _autoDownload = false;
  bool _wifiOnly = true;
  String _videoQuality = 'عالية';

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  // Note: All profile/theme methods have been moved to ProfileScreen

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
                            'subject=Support Request from ${AuthService().userProfile?['full_name']}'),
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

}
