import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  
  Uint8List? _imageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseService.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _nameController.text = user.userMetadata?['full_name'] as String? ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _saveChanges() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    
    try {
      final updates = <String, dynamic>{
        'full_name': _nameController.text.trim(),
      };
      
      await SupabaseService.instance.client
          .from('users')
          .update(updates)
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح', style: TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e), style: const TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _buildProfileHeader(isDark),
                const SizedBox(height: 32),
                _buildSection(
                  title: 'الحساب',
                  children: [
                    _buildGlassTextField(
                      label: 'الاسم الكامل',
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'المظهر',
                  children: [
                    _buildGlassToggle(
                      title: 'الوضع الليلي',
                      subtitle: 'تغيير سمة التطبيق',
                      value: themeProvider.isDarkMode,
                      onChanged: (v) => themeProvider.toggleTheme(),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                child: _imageBytes == null
                    ? Icon(Icons.person_outline_rounded, size: 60, color: AppColors.primaryPurple.withOpacity(0.5))
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: AppColors.getMutedTextColor(context),
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.getTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildGlassTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: AppColors.getMutedTextColor(context), fontSize: 13, fontFamily: 'Cairo'),
              prefixIcon: Icon(icon, color: AppColors.primaryPurple.withOpacity(0.7)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SwitchListTile(
            title: Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            subtitle: Text(subtitle, style: TextStyle(color: AppColors.getMutedTextColor(context), fontSize: 12, fontFamily: 'Cairo')),
            value: value,
            activeColor: AppColors.primaryPurple,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('حفظ التغييرات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Cairo')),
      ),
    );
  }
}
