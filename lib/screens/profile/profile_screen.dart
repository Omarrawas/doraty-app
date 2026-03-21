import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../models/course.dart';
import '../courses/course_details_screen.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic> _stats = {};
  int _selectedTabIndex = 0; // 0 for "متابعة", 1 for "المكتملة"
  List<Map<String, dynamic>> _enrolledData = [];
  bool _isCoursesLoading = true;
  bool _isEditing = false; // Added to toggle account info section
  
  // Profile editing data
  String? _userRole;
  Map<String, dynamic>? _specializedProfile;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  String? _currentAvatarUrl;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      final authService = AuthService();
      final dbService = DatabaseService.instance;

      final userData = await authService.getUserProfile();
      final stats = await _databaseService.getUserStats();
      
      if (userData != null) {
        final role = await dbService.getUserRole();
        Map<String, dynamic>? specialized;
        
        if (role == 'student') {
          specialized = await dbService.getStudentProfile(userData['id']);
        } else if (role == 'teacher') {
          specialized = await dbService.getTeacherProfile(userData['id']);
        }

        if (mounted) {
          setState(() {
            _userProfile = userData;
            _currentAvatarUrl = userData['avatar_url'];
            _userRole = role;
            _specializedProfile = specialized;
            _stats = stats;
          });
          _fetchUserCourses();
        }
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
      await _fetchUserData(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
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

      await _fetchUserData(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        // Upload image
        final userId = _userProfile?['id'];
        if (userId != null) {
          final imageUrl = await StorageService().uploadAvatar(
            _selectedImage!,
          );
          await _updateUserProfile({'avatar_url': imageUrl});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('الكاميرا', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('المعرض', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchUserCourses() async {
    if (!mounted) return;
    setState(() => _isCoursesLoading = true);
    try {
      final enrollments = await _databaseService.getEnrolledCoursesWithProgress();
      if (mounted) {
        setState(() {
          _enrolledData = enrollments;
          _isCoursesLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user courses: $e');
      if (mounted) setState(() => _isCoursesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isAuthenticated) {
      return Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: _buildLoginRequiredView(),
          ),
        ),
      );
    }

    if (_userRole == null && !_isCoursesLoading) {
      return Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: _buildCompleteProfilePrompt(),
          ),
        ),
      );
    }

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchUserData,
                  color: AppColors.primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildProfilePicture(),
                        const SizedBox(height: 15),
                        Text(
                          StringUtils.cleanTeacherName(
                              _userProfile?['full_name'] ?? _t('user')),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = !_isEditing;
                            });
                          },
                          icon: Icon(_isEditing ? Icons.check_circle_outline : Icons.edit_outlined, 
                            size: 18, 
                            color: _isEditing ? Colors.greenAccent : Colors.white
                          ),
                          label: Text(_isEditing ? 'تم' : 'تعديل الحساب',
                            style: TextStyle(color: _isEditing ? Colors.greenAccent : Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isEditing ? Colors.greenAccent : Colors.white,
                            side: BorderSide(color: _isEditing ? Colors.greenAccent.withOpacity(0.5) : Colors.white.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildCounterCard(
                              label: 'الدورات',
                              value: _stats['courses_count']?.toString() ?? '0',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCounterCard(
                              label: 'الشهادات',
                              value: _stats['certificates_count']?.toString() ?? '0',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      if (_isEditing) ...[
                        // Profile Sections
                        _buildSectionTitle('معلومات الحساب'),
                        _buildSettingCard(
                          icon: Icons.person_outline,
                          title: 'الاسم الكامل',
                          subtitle: _userProfile?['full_name'] ?? 'مستخدم',
                          onTap: _showNameEditDialog,
                        ),
                        
                        if (_userRole == 'student') ...[
                          _buildSettingCard(
                            icon: Icons.school_outlined,
                            title: 'المستوى الدراسي',
                            subtitle: _specializedProfile?['education_level'] == 'school' ? 'مدرسة' : 'جامعة',
                            onTap: _showEducationLevelDialog,
                          ),
                          _buildSettingCard(
                            icon: Icons.grade_outlined,
                            title: 'السنة الدراسية',
                            subtitle: _specializedProfile?['grade'] ?? 'غير محدد',
                            onTap: _showGradeDialog,
                          ),
                          if (_specializedProfile?['education_level'] == 'university')
                            _buildSettingCard(
                              icon: Icons.workspace_premium_outlined,
                              title: 'التخصص',
                              subtitle: _specializedProfile?['specialization'] ?? 'غير محدد',
                              onTap: _showSpecializationDialog,
                            ),
                        ] else if (_userRole == 'teacher') ...[
                          _buildSettingCard(
                            icon: Icons.workspace_premium_outlined,
                            title: 'التخصص',
                            subtitle: _specializedProfile?['specialization'] ?? 'غير محدد',
                            onTap: _showSpecializationDialog,
                          ),
                          _buildSettingCard(
                            icon: Icons.public_rounded,
                            title: 'البلد',
                            subtitle: _specializedProfile?['country'] ?? 'غير محدد',
                            onTap: _showCountryDialog,
                          ),
                          _buildSettingCard(
                            icon: Icons.phone_android,
                            title: 'رقم الهاتف',
                            subtitle: _specializedProfile?['phone_number'] ?? 'غير محدد',
                            onTap: _showPhoneDialog,
                          ),
                          _buildSettingCard(
                            icon: Icons.description_outlined,
                            title: 'النبذة الشخصية',
                            subtitle: _specializedProfile?['bio'] ?? 'أدخل نبذة عنك',
                            onTap: _showBioDialog,
                          ),
                        ],
                      ],


                        const SizedBox(height: 30),
                        
                        // Tab Switcher for Course Progress
                        _buildSectionTitle('نشاطي التعليمي'),
                        _buildTabSwitcher(),
                        
                        const SizedBox(height: 20),
                        
                        // Courses List
                        _isCoursesLoading 
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _buildCoursesList(),
                        
                        const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(10),
      child: Center(
        child: Text(
          _t('profile'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipOval(
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover)
                  : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                      ? Image.network(
                          _currentAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.person, size: 50, color: Colors.white),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNameEditDialog() {
    final nameController = TextEditingController(text: _userProfile?['full_name'] ?? '');
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعديل الاسم',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      hintText: 'أدخل الاسم الكامل',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newName = nameController.text.trim();
                            if (newName.isNotEmpty) {
                              await _updateUserProfile({'full_name': newName});
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('حفظ'),
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
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Cairo',
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
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
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
                          color: Colors.white.withOpacity(0.1),
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


  Widget _buildCounterCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _selectedTabIndex == 1 ? 0 : constraints.maxWidth / 2,
                right: _selectedTabIndex == 0 ? 0 : constraints.maxWidth / 2,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Center(
                        child: Text(
                          _t('current'), // "متابعة"
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Center(
                        child: Text(
                          _t('completed_status'), // "المكتملة"
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  void _showEducationLevelDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildSimpleSelectionDialog(
        title: 'المستوى الدراسي',
        options: {'school': 'مدرسة', 'university': 'جامعة'},
        currentValue: _specializedProfile?['education_level'],
        onSelect: (val) => _updateSpecializedProfile({'education_level': val}),
      ),
    );
  }

  void _showGradeDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildSimpleSelectionDialog(
        title: 'السنة الدراسية',
        options: {
          'الأول': 'الأول', 'الثاني': 'الثالث', 'الرابع': 'الرابع', 
          'الخامس': 'الخامس', 'السادس': 'السادس', 'السابع': 'السابع',
          'الثامن': 'الثامن', 'التاسع': 'التاسع', 'العاشر': 'العاشر',
          'الحادي عشر': 'الحادي عشر', 'بكالوريا': 'بكالوريا'
        },
        currentValue: _specializedProfile?['grade'],
        onSelect: (val) => _updateSpecializedProfile({'grade': val}),
      ),
    );
  }

  void _showSpecializationDialog() {
    _showTextInputDialog(
      title: 'التخصص',
      hint: 'أدخل تخصصك',
      initialValue: _specializedProfile?['specialization'],
      onSave: (val) => _updateSpecializedProfile({'specialization': val}),
    );
  }

  void _showCountryDialog() {
    _showTextInputDialog(
      title: 'البلد',
      hint: 'أدخل بلد الإقامة',
      initialValue: _specializedProfile?['country'],
      onSave: (val) => _updateSpecializedProfile({'country': val}),
    );
  }

  void _showPhoneDialog() {
    _showTextInputDialog(
      title: 'رقم الهاتف',
      hint: 'أدخل رقم هاتفك',
      initialValue: _specializedProfile?['phone_number'],
      keyboardType: TextInputType.phone,
      onSave: (val) => _updateSpecializedProfile({'phone_number': val}),
    );
  }

  void _showBioDialog() {
    _showTextInputDialog(
      title: 'النبذة الشخصية',
      hint: 'أدخل نبذة عنك',
      initialValue: _specializedProfile?['bio'],
      maxLines: 4,
      onSave: (val) => _updateSpecializedProfile({'bio': val}),
    );
  }

  Widget _buildSimpleSelectionDialog({
    required String title,
    required Map<String, String> options,
    required String? currentValue,
    required Function(String) onSelect,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                const SizedBox(height: 20),
                ...options.entries.map((e) => ListTile(
                  title: Text(e.value, style: const TextStyle(color: Colors.white)),
                  trailing: currentValue == e.key ? const Icon(Icons.check_circle, color: AppColors.primaryPurple) : null,
                  onTap: () {
                    onSelect(e.key);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTextInputDialog({
    required String title,
    required String hint,
    required String? initialValue,
    required Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      hintText: hint,
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white70)))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            onSave(controller.text.trim());
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('حفظ'),
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


  Widget _buildCoursesList() {
    // Match My Courses logic: 100% progress means completed
    final filteredData = _selectedTabIndex == 0 
        ? _enrolledData.where((e) => (e['progress_percentage'] ?? 0) < 100).toList()
        : _enrolledData.where((e) => (e['progress_percentage'] ?? 0) >= 100).toList();

    if (filteredData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(_selectedTabIndex == 0 ? Icons.play_circle_outline : Icons.check_circle_outline, 
                 size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              _selectedTabIndex == 0 ? 'لا توجد دورات حالية' : 'لا توجد دورات مكتملة',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final enrollment = filteredData[index];
        final courseJson = enrollment['courses'];
        if (courseJson == null) return const SizedBox.shrink();
        
        final course = Course.fromJson(courseJson);
        final progress = (enrollment['progress_percentage'] as num? ?? 0).toDouble() / 100;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailsScreen(course: course),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: course.imageUrl ?? '',
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 90,
                      height: 60,
                      color: Colors.white10,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 90,
                      height: 60,
                      color: Colors.white10,
                      child: const Icon(Icons.image_not_supported, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.instructorName,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedTabIndex == 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildCompleteProfilePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_ind_outlined, size: 80, color: Colors.amberAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              'أكمل إعداد حسابك',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'يرجى اختيار دورك (طالب أو مدرس) وإكمال بياناتك للوصول لكامل ميزات المنصة',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 8,
              ),
              child: const Text(
                'إكمال الملف الشخصي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, size: 80, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Text(
              _t('login_required_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _t('login_required_desc'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 8,
                shadowColor: AppColors.primaryPurple.withOpacity(0.5),
              ),
              child: Text(
                _t('login_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
