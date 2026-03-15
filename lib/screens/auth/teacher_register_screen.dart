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

class TeacherRegisterScreen extends StatefulWidget {
  const TeacherRegisterScreen({super.key});

  @override
  State<TeacherRegisterScreen> createState() => _TeacherRegisterScreenState();
}

class _TeacherRegisterScreenState extends State<TeacherRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);
  
  // State variables
  final _fullNameController = TextEditingController();
  String _userEmail = '';

  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _countryController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  
  // Intent
  bool _giveFullCourses = false;
  bool _teachPrivateHours = false;

  // Files
  File? _cvFile;
  File? _certificateFile;
  File? _profileImage;

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
    _phoneController.dispose();
    _specializationController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
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
    
    if (!_giveFullCourses && !_teachPrivateHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('select_sub_type_error'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = DatabaseService();
      
      String? userId = SupabaseService.instance.currentUserId;
      
      if (userId == null) {
        throw _t('fail_get_user_id');
      }

      // Upload Documents to GitHub
      String? cvUrl;
      String? certificateUrl;
      String? avatarUrl;

      if (_profileImage != null) {
        final avatarPath = 'teachers/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.${_profileImage!.path.split('.').last}';
        avatarUrl = await GitHubStorageService.uploadFile(
          file: _profileImage!,
          path: avatarPath,
          commitMessage: 'Upload profile photo for teacher: $userId',
        );
      }
      
      if (_cvFile != null) {
        final cvPath = 'teachers/$userId/cv_${DateTime.now().millisecondsSinceEpoch}.${_cvFile!.path.split('.').last}';
        cvUrl = await GitHubStorageService.uploadFile(
          file: _cvFile!,
          path: cvPath,
          commitMessage: 'Upload CV for teacher: $userId',
        );
      }
      
      if (_certificateFile != null) {
        final certPath = 'teachers/$userId/cert_${DateTime.now().millisecondsSinceEpoch}.${_certificateFile!.path.split('.').last}';
        certificateUrl = await GitHubStorageService.uploadFile(
          file: _certificateFile!,
          path: certPath,
          commitMessage: 'Upload Certificate for teacher: $userId',
        );
      }

      // Save Teacher Profile
      await databaseService.saveTeacherProfile({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'email': _userEmail,
        'phone_number': _phoneController.text.trim(),
        'subscription_type': _giveFullCourses && _teachPrivateHours ? 'both' : (_giveFullCourses ? 'courses' : 'tutoring'),
        'specialization': _specializationController.text.trim(),
        'country': _countryController.text.trim(),
        'bio': _bioController.text.trim(),
        'cv_url': cvUrl,
        'certificates_url': certificateUrl,
        'avatar_url': avatarUrl,
        'status': 'pending',
      });

      if (mounted) {
        // Refresh Auth Profile to ensure the app knows registration is complete
        await Provider.of<AuthService>(context, listen: false).loadUserProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('success_submit_teacher')),
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
        title: Text(_t('register_new_coach'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                       _buildHeader(_t('personal_info')),
                       const SizedBox(height: 16),
                       _buildGlassField(
                         controller: _phoneController,
                         label: '${_t('phone_number_label')} ${_t('required_suffix')}',
                         icon: Icons.phone_android_rounded,
                         keyboardType: TextInputType.phone,
                         validator: (v) => v!.isEmpty ? _t('required_field') : null,
                       ),
                                            const SizedBox(height: 32),
                       _buildHeader(_t('participation_plans')),
                       Text(
                         _t('participation_intent_label'),
                         style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      _buildSubscriptionOption(
                        _t('give_full_courses_label'),
                        _giveFullCourses,
                        (v) => setState(() => _giveFullCourses = v!),
                      ),
                      _buildSubscriptionOption(
                        _t('teach_private_hours_label'),
                        _teachPrivateHours,
                        (v) => setState(() => _teachPrivateHours = v!),
                      ),



                      const SizedBox(height: 32),
                      _buildHeader(_t('professional_info')),
                      _buildGlassField(
                        controller: _specializationController,
                        label: '${_t('specialization_label')} ${_t('required_suffix')}',
                        icon: Icons.workspace_premium_outlined,
                        validator: (v) => v!.isEmpty ? _t('required_field') : null,
                      ),
                      const SizedBox(height: 16),
                      _buildGlassField(
                        controller: _countryController,
                        label: _t('country_label'),
                        icon: Icons.public_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildFilePickerSection(
                        _t('cv_label'),
                        _cvFile,
                        () => _pickFile(true),
                      ),
                      const SizedBox(height: 12),
                      _buildFilePickerSection(
                        _t('certificates_label'),
                        _certificateFile,
                        () => _pickFile(false),
                      ),
                      const SizedBox(height: 16),
                      _buildGlassField(
                        controller: _bioController,
                        label: _t('short_bio_hint'),
                        icon: Icons.description_outlined,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 48),
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

  Widget _buildSubscriptionOption(String title, bool value, Function(bool?) onChanged) {
    return Theme(
      data: ThemeData(unselectedWidgetColor: Colors.white70),
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryPurple,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildFilePickerSection(String title, File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(file != null ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: file != null ? Colors.greenAccent : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(
                        file != null ? file.path.split('/').last : _t('no_file_selected'),
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(file != null ? _t('change') : _t('choose'), style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
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
            _t('submit_request'),
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
