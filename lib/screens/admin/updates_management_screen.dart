import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdatesManagementScreen extends StatefulWidget {
  const UpdatesManagementScreen({super.key});

  @override
  State<UpdatesManagementScreen> createState() => _UpdatesManagementScreenState();
}

class _UpdatesManagementScreenState extends State<UpdatesManagementScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  final _versionController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isMandatory = false;
  bool _isSubmitting = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _db.addAppUpdate(
        versionName: _versionController.text.trim(),
        downloadUrl: _urlController.text.trim(),
        releaseNotes: _notesController.text.trim(),
        isMandatory: _isMandatory,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('update_success')), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(_t('add_update')),
                        SizedBox(height: 20),
                        _buildTextField(
                          controller: _versionController,
                          label: _t('version_name'),
                          hint: _currentVersion,
                          icon: Icons.numbers,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _urlController,
                          label: _t('download_url'),
                          hint: 'https://...',
                          icon: Icons.link,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          controller: _notesController,
                          label: _t('release_notes'),
                          hint: 'إصلاح بعض المشاكل وإضافة ميزات جديدة...',
                          icon: Icons.note_add,
                          maxLines: 4,
                        ),
                        SizedBox(height: 20),
                        _buildMandatorySwitch(),
                        SizedBox(height: 30),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 10),
          Text(
            _t('app_updates'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.getTextColor(context),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.getTextColor(context), fontSize: 13, fontFamily: 'Cairo'),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.getTextColor(context)),
              prefixIcon: Icon(icon, color: AppColors.getTextColor(context), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMandatorySwitch() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isMandatory ? AppColors.primaryPurple.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMandatory ? AppColors.primaryPurple.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isMandatory ? Icons.warning_rounded : Icons.info_outline,
            color: _isMandatory ? Colors.orange : Colors.white,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('is_mandatory_label'),
                  style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                Text(
                  _isMandatory ? 'سيُجبر المستخدم على التحديث' : 'تحديث اختياري يظهر كتنبيه فقط',
                  style: TextStyle(color: AppColors.getTextColor(context), fontSize: 11, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          Switch(
            value: _isMandatory,
            onChanged: (v) => setState(() => _isMandatory = v),
            activeColor: AppColors.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitUpdate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: AppColors.getTextColor(context), strokeWidth: 2),
              )
            : Text(
                _t('add_update'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
      ),
    );
  }
}
