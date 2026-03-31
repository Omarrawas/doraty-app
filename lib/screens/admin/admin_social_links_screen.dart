import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appSnackBar(context, 'خطأ في جلب الروابط');
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
      appSnackBar(context, 'تم حفظ الحسابات بنجاح!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      appSnackBar(context, 'حدث خطأ أثناء الحفظ');
    }
  }

  void appSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _t(String key) => AppStrings.get(
    key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_t('admin_social_links_side')), // "حسابات التواصل"
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: DynamicGradientBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: ListView(
                  padding: EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.getGlassColor(context, opacity: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link, color: AppColors.primaryPurple, size: 28),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _t('admin_social_links_desc'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            _t('social_url_hint'),
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 25),

                          ..._controllers.keys.map((key) => _buildLinkField(key)),

                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveLinks,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isSaving
                                  ? CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      _t('save_changes'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLinkField(String platformKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _controllers[platformKey],
        decoration: InputDecoration(
          labelText: _t(platformKey),
          hintText: 'https://...',
          prefixIcon: Icon(_icons[platformKey], color: AppColors.primaryPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        ),
        keyboardType: TextInputType.url,
      ),
    );
  }
}
