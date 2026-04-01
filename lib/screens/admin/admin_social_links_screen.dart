import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';

class AdminSocialLinksScreen extends StatefulWidget {
  const AdminSocialLinksScreen({super.key});

  @override
  State<AdminSocialLinksScreen> createState() => _AdminSocialLinksScreenState();
}

class _AdminSocialLinksScreenState extends State<AdminSocialLinksScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, TextEditingController> _controllers = {
    'social_facebook': TextEditingController(),
    'social_instagram': TextEditingController(),
    'social_youtube': TextEditingController(),
    'social_whatsapp': TextEditingController(),
    'social_x_twitter': TextEditingController(),
    'social_telegram': TextEditingController(),
    'social_tiktok': TextEditingController(),
    'social_linkedin': TextEditingController(),
  };

  final Map<String, IconData> _icons = {
    'social_facebook': Icons.facebook,
    'social_instagram': Icons.camera_alt,
    'social_youtube': Icons.play_arrow,
    'social_whatsapp': Icons.chat,
    'social_x_twitter': Icons.close,
    'social_telegram': Icons.send,
    'social_tiktok': Icons.music_note,
    'social_linkedin': Icons.work,
  };

  final Map<String, Color> _platformColors = {
    'social_facebook': const Color(0xFF1877F2),
    'social_instagram': const Color(0xFFE4405F),
    'social_youtube': const Color(0xFFFF0000),
    'social_whatsapp': const Color(0xFF25D366),
    'social_x_twitter': const Color(0xFF000000),
    'social_telegram': const Color(0xFF0088CC),
    'social_tiktok': const Color(0xFF000000),
    'social_linkedin': const Color(0xFF0077B5),
  };

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLinks() async {
    try {
      final links = await _dbService.getSocialLinks();
      if (!mounted) return;
      setState(() {
        for (var entry in links.entries) {
          if (_controllers.containsKey(entry.key)) {
            _controllers[entry.key]?.text = entry.value;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(_t('error_loading_links'), isError: true);
    }
  }

  Future<void> _saveLinks() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, String> dataToSave = {};
      _controllers.forEach((key, controller) {
        dataToSave[key] = controller.text.trim();
      });

      await _dbService.saveSocialLinks(dataToSave);
      
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackBar(_t('social_links_saved_success'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackBar(_t('error_saving_links'), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.greenAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _t(String key) => AppStrings.get(
    key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_t('admin_social_links_side')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: DynamicGradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
            : SafeArea(
                child: Column(
                  children: [
                    _buildHeaderSection(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          ..._controllers.keys.map((key) => _buildModernLinkField(key)),
                          const SizedBox(height: 30),
                          _buildSaveButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: AppColors.primaryPurple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('admin_social_links_desc'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('social_url_hint'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextColor(context).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLinkField(String platformKey) {
    final color = _platformColors[platformKey] ?? AppColors.primaryPurple;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.1),
              ),
            ),
            child: TextField(
              controller: _controllers[platformKey],
              style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14),
              decoration: InputDecoration(
                labelText: _t(platformKey),
                labelStyle: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
                hintText: 'https://...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.3)),
                prefixIcon: Icon(_icons[platformKey], color: color),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple,
            AppColors.primaryPurple.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveLinks,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                _t('save_changes'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
