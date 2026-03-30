import 'package:flutter/material.dart';
// No import needed here
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/github_storage_service.dart' hide FileType;
import '../../core/utils/error_utils.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  final bool isCompletingProfile;
  final String? initialRole;
  const RegisterScreen({super.key, this.isCompletingProfile = false, this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common Fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late String _selectedRole; 

  // Student Specific Fields
  String _educationLevel = 'school'; // 'school' or 'university'
  String? _selectedGrade;
  String? _selectedUniversityYear;
  final TextEditingController _studentSpecializationController = TextEditingController();
  bool _termsAccepted = true;
  File? _profileImage;

  // Teacher Specific Fields
  final TextEditingController _teacherPhoneController = TextEditingController();
  final TextEditingController _teacherSpecializationController = TextEditingController();
  final TextEditingController _teacherCountryController = TextEditingController();
  final TextEditingController _teacherBioController = TextEditingController();
  bool _giveFullCourses = false;
  bool _teachPrivateHours = false;
  File? _cvFile;
  File? _certificateFile;

  // Lists for Grade/Year
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

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'student';
    // If completing profile, pre-fill from already authenticated user if possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.isAuthenticated) {
        final profile = auth.userProfile;
        if (profile != null) {
          _nameController.text = profile['full_name'] ?? '';
          _emailController.text = profile['email'] ?? '';
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentSpecializationController.dispose();
    _teacherPhoneController.dispose();
    _teacherSpecializationController.dispose();
    _teacherCountryController.dispose();
    _teacherBioController.dispose();
    super.dispose();
  }

  // --- Image/File Picking ---
  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _profileImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickFile(bool isCV) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isCV) {
          _cvFile = File(result.files.single.path!);
        } else {
          _certificateFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _register() async {
    if (widget.isCompletingProfile) {
      await _completeProfile();
    } else {
      await _signUp();
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar(_t('pass_dont_match'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (mounted) {
        context.go('/register/complete');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(ErrorUtils.getFriendlyErrorMessage(e));
      }
    }
  }

  Future<void> _completeProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? userId = SupabaseService.instance.currentUserId;
    if (userId == null) throw _t('fail_get_user_id');

    if (_selectedRole == 'student' && !_termsAccepted) {
      _showErrorSnackBar('الرجاء الموافقة على الشروط والأحكام');
      return;
    }

    if (_selectedRole == 'teacher' && !_giveFullCourses && !_teachPrivateHours) {
      _showErrorSnackBar(_t('select_sub_type_error'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();

      // Upload Files to GitHub
      String? avatarUrl;
      String? cvUrl;
      String? certUrl;

      if (_profileImage != null) {
        final path = '${_selectedRole}s/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.${_profileImage!.path.split('.').last}';
        avatarUrl = await GitHubStorageService.uploadFile(file: _profileImage!, path: path, commitMessage: 'Avatar for $userId');
      }

      if (_selectedRole == 'teacher') {
        if (_cvFile != null) {
          final path = 'teachers/$userId/cv_${DateTime.now().millisecondsSinceEpoch}.${_cvFile!.path.split('.').last}';
          cvUrl = await GitHubStorageService.uploadFile(file: _cvFile!, path: path, commitMessage: 'CV for $userId');
        }
        if (_certificateFile != null) {
          final path = 'teachers/$userId/cert_${DateTime.now().millisecondsSinceEpoch}.${_certificateFile!.path.split('.').last}';
          certUrl = await GitHubStorageService.uploadFile(file: _certificateFile!, path: path, commitMessage: 'Cert for $userId');
        }
      }

      // Save Role-Specific Profile
      if (_selectedRole == 'student') {
        await dbService.saveStudentProfile({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'education_level': _educationLevel,
          'grade': _educationLevel == 'school' ? _selectedGrade : _selectedUniversityYear,
          'specialization': _educationLevel == 'university' ? _studentSpecializationController.text.trim() : null,
          'terms_accepted': _termsAccepted,
          'avatar_url': avatarUrl,
        });
      } else {
        await dbService.saveTeacherProfile({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone_number': _teacherPhoneController.text.trim(),
          'subscription_type': _giveFullCourses && _teachPrivateHours ? 'both' : (_giveFullCourses ? 'courses' : 'tutoring'),
          'specialization': _teacherSpecializationController.text.trim(),
          'country': _teacherCountryController.text.trim(),
          'bio': _teacherBioController.text.trim(),
          'cv_url': cvUrl,
          'certificates_url': certUrl,
          'avatar_url': avatarUrl,
          'status': 'pending',
        });
      }

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        await authService.loadUserProfile();
        
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(_t('account_created_success')), backgroundColor: Colors.green),
        );
        
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(ErrorUtils.getFriendlyErrorMessage(e));
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  SizedBox(height: 20),
                  Text(widget.isCompletingProfile ? 'إكمال الملف الشخصي' : _t('register_title'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), fontFamily: 'Cairo')),
                  Text(widget.isCompletingProfile ? 'الرجاء تزويدنا ببعض المعلومات الإضافية' : _t('register_subtitle'), style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context, secondary: true), fontFamily: 'Cairo')),
                  SizedBox(height: 30),
                  
                  if (widget.isCompletingProfile) ...[
                    _buildProfileImagePicker(),
                    SizedBox(height: 30),
                    _buildPremiumRoleSelector(),
                    SizedBox(height: 20),
                    // Role-Specific Sections
                    if (_selectedRole == 'student') _buildStudentSection() else _buildTeacherSection(),
                  ] else ...[
                    _buildHeader(_t('personal_info')),
                    _buildGlassField(controller: _nameController, label: _t('name'), icon: Icons.person_outline, validator: (v) => v!.isEmpty ? _t('required_field') : null),
                    SizedBox(height: 16),
                    _buildGlassField(controller: _emailController, label: _t('email_label'), icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? _t('required_field') : null),
                    SizedBox(height: 32),
                    _buildHeader(_t('security_header')),
                    _buildGlassField(
                      controller: _passwordController,
                      label: _t('password_label'),
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: (v) => v!.length < 6 ? _t('pass_min_char') : null,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.getTextColor(context).withOpacity(0.70)),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildGlassField(
                      controller: _confirmPasswordController,
                      label: _t('confirm_password_label'),
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.getTextColor(context).withOpacity(0.70)),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 40),
                  _buildRegisterButton(widget.isCompletingProfile),

                  SizedBox(height: 20),
                  if (!widget.isCompletingProfile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_t('already_have_account'), style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 14, fontFamily: 'Cairo')),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(' ${_t('login_now')}', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Components ---
  Widget _buildTopBar() {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.locale == 'ar';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextColor(context).withOpacity(0.70)), onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/');
          }
        }),
        GestureDetector(
          onTap: () => localeProvider.setLocale(isArabic ? 'en' : 'ar'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.getGlassColor(context, opacity: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.getBorderColor(context))),
            child: Row(
              children: [
                Icon(Icons.language_rounded, size: 18, color: AppColors.getTextColor(context, secondary: true)),
                SizedBox(width: 8),
                Text(isArabic ? 'English' : 'العربية', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfileImage,
        child: Stack(
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.getBorderColor(context), width: 2)),
              child: ClipOval(
                child: _profileImage != null 
                  ? Image.file(_profileImage!, fit: BoxFit.cover) 
                  : Container(color: AppColors.getTextColor(context).withOpacity(0.10), child: Icon(Icons.person, size: 50, color: AppColors.getTextColor(context).withOpacity(0.60))),
              ),
            ),
            Positioned(bottom: 0, right: 0, child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primaryPurple, shape: BoxShape.circle), child: Icon(Icons.camera_alt, color: Colors.white, size: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumRoleSelector() {
    final isStudent = _selectedRole == 'student';
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.getGlassColor(context, opacity: 0.2), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildRoleBtn(_t('student_role'), Icons.school_rounded, isStudent, () => setState(() => _selectedRole = 'student')),
          _buildRoleBtn(_t('teacher_role'), Icons.co_present_rounded, !isStudent, () => setState(() => _selectedRole = 'teacher')),
        ],
      ),
    );
  }

  Widget _buildRoleBtn(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(gradient: active ? AppColors.primaryGradient : null, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: active ? Colors.white : AppColors.getTextColor(context, secondary: true), size: 18),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? Colors.white : AppColors.getTextColor(context, secondary: true), fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ]),
        ),
      ),
    );
  }

  Widget _buildStudentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(_t('educational_info')),
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.getGlassColor(context, opacity: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _buildTypeBtn(_t('school'), 'school'),
            _buildTypeBtn(_t('university'), 'university'),
          ]),
        ),
        SizedBox(height: 16),
        if (_educationLevel == 'school')
          _buildGlassDropdown(label: _t('grade_level_label'), icon: Icons.school_outlined, value: _selectedGrade, items: _schoolGrades, onChanged: (v) => setState(() => _selectedGrade = v))
        else ...[
          _buildGlassField(controller: _studentSpecializationController, label: _t('specialization'), icon: Icons.workspace_premium_outlined, validator: (v) => v!.isEmpty ? _t('required_field') : null),
          SizedBox(height: 12),
          _buildGlassDropdown(label: _t('academic_year_label'), icon: Icons.calendar_month_outlined, value: _selectedUniversityYear, items: _universityYears, onChanged: (v) => setState(() => _selectedUniversityYear = v)),
        ],
        SizedBox(height: 16),
        Row(children: [
          Checkbox(value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v!), activeColor: AppColors.primaryPurple),
          Text(_t('terms_accept_label'), style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13, fontFamily: 'Cairo')),
        ]),
      ],
    );
  }

  Widget _buildTeacherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(_t('professional_info')),
        _buildGlassField(controller: _teacherPhoneController, label: _t('phone_number_label'), icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? _t('required_field') : null),
        SizedBox(height: 16),
        _buildGlassField(controller: _teacherSpecializationController, label: _t('specialization'), icon: Icons.workspace_premium_outlined, helperText: 'اختصار المسمى الوظيفي (مثال: مصور، مصمم، مبرمج...)', maxLength: 30, validator: (v) => v!.isEmpty ? _t('required_field') : null),
        SizedBox(height: 16),
        _buildGlassField(controller: _teacherCountryController, label: _t('country_label'), icon: Icons.public_rounded),
        SizedBox(height: 16),
        _buildHeader(_t('participation_plans')),
        _buildSubscriptionOption(_t('give_full_courses_label'), _giveFullCourses, (v) => setState(() => _giveFullCourses = v!)),
        _buildSubscriptionOption(_t('teach_private_hours_label'), _teachPrivateHours, (v) => setState(() => _teachPrivateHours = v!)),
        SizedBox(height: 16),
        _buildFilePickerSection(_t('cv_label'), _cvFile, () => _pickFile(true)),
        SizedBox(height: 12),
        _buildFilePickerSection(_t('certificates_label'), _certificateFile, () => _pickFile(false)),
        SizedBox(height: 16),
        _buildGlassField(controller: _teacherBioController, label: _t('short_bio_hint'), icon: Icons.description_outlined, maxLines: 3),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Padding(padding: EdgeInsets.only(top: 16, bottom: 12), child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), fontFamily: 'Cairo')));
  }

  Widget _buildTypeBtn(String label, String value) {
    final active = _educationLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _educationLevel = value; _selectedGrade = null; _selectedUniversityYear = null; }),
        child: Container(padding: EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: active ? AppColors.primaryPurple : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.getTextColor(context, secondary: true), fontWeight: active ? FontWeight.bold : FontWeight.normal)))),
      ),
    );
  }

  Widget _buildSubscriptionOption(String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(title: Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14, fontFamily: 'Cairo')), value: value, onChanged: onChanged, activeColor: AppColors.primaryPurple, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading);
  }

  Widget _buildFilePickerSection(String title, File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.getGlassColor(context, opacity: 0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.getBorderColor(context))),
        child: Row(children: [
          Icon(file != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: file != null ? Colors.greenAccent : AppColors.getTextColor(context, secondary: true), size: 20),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 13)), Text(file != null ? file.path.split('/').last : _t('no_file_selected'), style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 11), overflow: TextOverflow.ellipsis)])),
          Text(file != null ? _t('change') : _t('choose'), style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
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
    bool enabled = true,
    int? maxLength,
    String? helperText,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.getGlassColor(context, opacity: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorderColor(context))),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textAlign: TextAlign.right,
        enabled: enabled,
        maxLength: maxLength,
        style: TextStyle(
            color: enabled ? AppColors.getTextColor(context) : AppColors.getTextColor(context, secondary: true), fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 14),
          helperText: helperText,
          helperStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.38), fontSize: 10),
          prefixIcon: Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.60), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          counterStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.38), fontSize: 10),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildGlassDropdown({required String label, required IconData icon, required String? value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.getGlassColor(context, opacity: 0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.getBorderColor(context))),
      child: DropdownButtonFormField<String>(
        value: value, 
        dropdownColor: AppColors.getSurfaceColor(context), 
        icon: Icon(Icons.arrow_drop_down, color: AppColors.getTextColor(context, secondary: true)),
        style: TextStyle(color: AppColors.getTextColor(context), fontSize: 15),
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 14), 
          prefixIcon: Icon(icon, color: AppColors.getTextColor(context, secondary: true), size: 20), 
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged, validator: (v) => v == null ? _t('required_field') : null,
      ),
    );
  }

  Widget _buildRegisterButton(bool isCompletingProfile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))]),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isLoading ? CircularProgressIndicator(color: AppColors.getTextColor(context)) : Text(isCompletingProfile ? 'إكمال عملية التسجيل' : 'متابعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context), fontFamily: 'Cairo')),
      ),
    );
  }
}
