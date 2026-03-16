import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/github_storage_service.dart' hide FileType;
import '../../core/utils/error_utils.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../main.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);
  
  // State variables
  final _fullNameController = TextEditingController();
  String _userEmail = '';

  final _specializationController = TextEditingController();

  bool _isLoading = false;
  bool _termsAccepted = true;
  File? _profileImage;

  // Education Level
  String _educationLevel = 'school'; // 'school' or 'university'
  String? _selectedGrade;
  String? _selectedUniversityYear;

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

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  void _prefillData() {
    final user = SupabaseService.instance.client.auth.currentUser;
    if (user != null) {
      final authService = Provider.of<AuthService>(context, listen: false);
      setState(() {
        _userEmail = user.email ?? '';
        
        // Try to get name from multiple sources
        String? initialName = user.userMetadata?['full_name'] ?? 
                             user.userMetadata?['display_name'] ?? 
                             authService.userProfile?['full_name'];
        
        // Fallback to email prefix if name is empty
        if ((initialName == null || initialName.isEmpty) && _userEmail.isNotEmpty) {
          initialName = _userEmail.split('@').first;
        }
        
        _fullNameController.text = initialName ?? '';
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _profileImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء الموافقة على الشروط والأحكام')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = DatabaseService();
      
      final String? userId = SupabaseService.instance.currentUserId;
      
      if (userId == null) {
        throw 'يجب تسجيل الدخول أولاً لإكمال الملف الشخصي';
      }

      // Upload Profile Image to GitHub
      String? avatarUrl;
      if (_profileImage != null) {
        final avatarPath = 'students/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.${_profileImage!.path.split('.').last}';
        avatarUrl = await GitHubStorageService.uploadFile(
          file: _profileImage!,
          path: avatarPath,
          commitMessage: 'Upload profile photo for student: $userId',
        );
      }

      // Save Student Profile
      await databaseService.saveStudentProfile({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'email': _userEmail,
        'education_level': _educationLevel,
        'grade': _educationLevel == 'school' ? _selectedGrade : _selectedUniversityYear,
        'specialization': _educationLevel == 'university' ? _specializationController.text.trim() : null,
        'terms_accepted': _termsAccepted,
        'avatar_url': avatarUrl,
      });

      if (mounted) {
        // Refresh Auth Profile to ensure the app knows registration is complete
        await Provider.of<AuthService>(context, listen: false).loadUserProfile();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء حساب الطالب بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('تسجيل طالب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileImagePicker(),
                      const SizedBox(height: 24),
                      _buildUserInfoCard(),
                       
                       const SizedBox(height: 32),
                       _buildHeader(_t('educational_info')),
                      _buildEducationTypeSelector(),
                      const SizedBox(height: 20),
                      
                      if (_educationLevel == 'school')
                        _buildGlassDropdown(
                          label: _t('grade_level_label'),
                          icon: Icons.school_outlined,
                          value: _selectedGrade,
                          items: _schoolGrades,
                          onChanged: (v) => setState(() => _selectedGrade = v),
                          validator: (v) => v == null ? _t('required_field') : null,
                        )
                      else ...[
                        _buildGlassField(
                          controller: _specializationController,
                          label: '${_t('university_specialization_label')} ${_t('required_suffix')}',
                          icon: Icons.workspace_premium_outlined,
                          validator: (v) => v!.isEmpty ? _t('required_field') : null,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassDropdown(
                          label: _t('academic_year_label'),
                          icon: Icons.calendar_month_outlined,
                          value: _selectedUniversityYear,
                          items: _universityYears,
                          onChanged: (v) => setState(() => _selectedUniversityYear = v),
                          validator: (v) => v == null ? _t('required_field') : null,
                        ),
                      ],


 
                         const SizedBox(height: 24),
                         _buildTermsCheckbox(),

                      const SizedBox(height: 40),
                      _buildSubmitButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Column(
      children: [
        _buildGlassField(
          controller: _fullNameController,
          label: _t('name'),
          icon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? _t('required_field') : null,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: _buildReadOnlyInfo(Icons.email_outlined, _userEmail),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildEducationTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(_t('school'), 'school'),
          ),
          Expanded(
            child: _buildTypeButton(_t('university'), 'university'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    final isSelected = _educationLevel == value;
    return GestureDetector(
      onTap: () => setState(() {
        _educationLevel = value;
        _selectedGrade = null;
        _selectedUniversityYear = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: Icon(icon, color: Colors.white70),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: AppColors.darkBackground,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: Icon(icon, color: Colors.white70),
              border: InputBorder.none,
            ),
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item, textAlign: TextAlign.right),
            )).toList(),
            onChanged: onChanged,
            validator: validator ?? (v) => v == null ? _t('required_field') : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Theme(
          data: ThemeData(unselectedWidgetColor: Colors.white70),
          child: Checkbox(
            value: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v!),
            activeColor: AppColors.primaryPurple,
          ),
        ),
        Expanded(
          child: Text(
            _t('terms_accept_label'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.primaryPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _t('create_account'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfileImage,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _profileImage != null
                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.white.withOpacity(0.1),
                        child: const Icon(Icons.person, size: 60, color: Colors.white70),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
