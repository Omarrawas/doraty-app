import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';

class SecuritySettingsScreen extends StatefulWidget {
  SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLoading = true;
  bool _screenshotProtectionEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await SupabaseService.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'screenshot_protection_enabled')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            final value = response['setting_value'] as String?;
            _screenshotProtectionEnabled = value?.toLowerCase() == 'true';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('فشل تحميل الإعدادات');
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      await SupabaseService.instance.client
          .from('app_settings')
          .upsert({
        'setting_key': 'screenshot_protection_enabled',
            'setting_value': _screenshotProtectionEnabled.toString(),
            'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'setting_key');

      if (mounted) {
        _showSuccessSnackBar('تم حفظ الإعدادات بنجاح');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        _showErrorSnackBar('فشل حفظ الإعدادات');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات الأمان', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primaryPurple,
        elevation: 0,
      ),
      body: DynamicGradientBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
            : SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    _buildHeaderCard(),
                    SizedBox(height: 24),

                    // Screenshot Protection Setting
                    _buildSettingCard(
                      icon: Icons.screenshot_outlined,
                      title: 'حماية لقطات الشاشة',
                      description:
                          'منع المستخدمين العاديين من أخذ لقطات شاشة أو تسجيل فيديو للتطبيق',
                      value: _screenshotProtectionEnabled,
                      onChanged: (value) {
                        setState(() {
                          _screenshotProtectionEnabled = value;
                        });
                      },
                    ),

                    SizedBox(height: 24),

                    // Info Card
                    _buildInfoCard(),

                    SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.8),
            AppColors.primaryBlue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.security,
              color: AppColors.getTextColor(context),
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الأمان والخصوصية',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تحكم في سياسات الأمان للتطبيق',
                  style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.70),
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getMutedTextColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.getTextColor(context), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.accentPink,
                activeTrackColor: AppColors.accentPink.withOpacity(0.5),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: AppColors.getTextColor(context, secondary: true),
              fontSize: 14,
              fontFamily: 'Cairo',
              height: 1.5,
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: value
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value
                    ? Colors.green.withOpacity(0.5)
                    : Colors.orange.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  value ? Icons.lock : Icons.lock_open,
                  color: value ? Colors.green : Colors.orange,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value
                        ? 'الحماية مفعلة - المستخدمون العاديون لا يمكنهم أخذ لقطات شاشة'
                        : 'الحماية معطلة - جميع المستخدمين يمكنهم أخذ لقطات شاشة',
                    style: TextStyle(
                      color: value ? Colors.green : Colors.orange,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade300,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملاحظات هامة:',
                  style: TextStyle(
                    color: Colors.blue.shade200,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• المستخدمون الأدمن يمكنهم دائماً أخذ لقطات شاشة بغض النظر عن هذا الإعداد\n'
                  '• هذه الميزة تعمل فقط على أجهزة Android\n'
                  '• التغييرات تطبق فوراً على المستخدمين الجدد\n'
                  '• المستخدمون الحاليون يحتاجون لإعادة تسجيل الدخول',
                  style: TextStyle(
                    color: Colors.blue.shade100,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.getTextColor(context),
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'حفظ التغييرات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
