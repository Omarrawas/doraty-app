import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/string_utils.dart';
import 'teacher_profile_screen.dart';
import '../../core/theme/app_colors.dart';

class TeachersListScreen extends StatefulWidget {
  const TeachersListScreen({super.key});

  @override
  State<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends State<TeachersListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<String> _allSubjects = [];
  String _searchQuery = '';
  String _selectedSubject = 'all';
  bool _isLoading = true;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers({bool forceRefresh = false}) async {
    try {
      if (forceRefresh && mounted) setState(() => _isLoading = true);

      final teachers =
          await _databaseService.getAllTeachers(forceRefresh: forceRefresh);

      // Extract unique subjects for chips
      final Set<String> subjectsSet = {};
      for (var t in teachers) {
        final userData = t['users'] as Map<String, dynamic>?;
        final subjects = userData?['subjects'] as List?;
        if (subjects != null) {
          for (var s in subjects) {
            if (s != null && s.toString().isNotEmpty) {
              subjectsSet.add(s.toString());
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allTeachers = teachers;
          _allSubjects = subjectsSet.toList()..sort();
          _filterTeachers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterTeachers() {
    List<Map<String, dynamic>> results = _allTeachers;

    // Filter by subject
    if (_selectedSubject != 'all') {
      results = results.where((t) {
        final userData = t['users'] as Map<String, dynamic>?;
        final subjects = userData?['subjects'] as List?;
        return subjects?.contains(_selectedSubject) ?? false;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      results = results.where((t) {
        final userData = t['users'] as Map<String, dynamic>?;
        final name = (userData?['full_name'] ?? userData?['name'] ?? '')
            .toString()
            .toLowerCase();
        final bio = (userData?['bio'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            bio.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredTeachers = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    double childAspectRatio = 1.5;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.75;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.75;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadTeachers(forceRefresh: true),
        color: AppColors.primaryPurple,
        backgroundColor: AppColors.getGlassColor(context),
        child: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchSection(),
                _buildSubjectChips(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryPurple))
                      : _filteredTeachers.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.3),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_off_outlined,
                                          size: 64,
                                          color: Colors.white.withOpacity(0.5)),
                                      const SizedBox(height: 16),
                                      Text(
                                        _t('no_teachers_found'),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredTeachers.length,
                              itemBuilder: (context, index) =>
                                  _buildTeacherCard(_filteredTeachers[index]),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'المعلمون المتاحون',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getGlassColor(context, opacity: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            _searchQuery = value;
            _filterTeachers();
          },
          decoration: InputDecoration(
            hintText: 'ابحث عن معلم...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChips() {
    if (_allSubjects.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _allSubjects.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final subject = isAll ? 'all' : _allSubjects[index - 1];
          final label = isAll ? 'الكل' : _allSubjects[index - 1];
          final isSelected = _selectedSubject == subject;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedSubject = subject;
                  _filterTeachers();
                });
              },
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: AppColors.primaryPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final userData = teacher['users'] as Map<String, dynamic>?;
    final name = StringUtils.cleanTeacherName(
        userData?['full_name'] ?? userData?['name'] ?? _t('teacher'));
    final avatarUrl = userData?['photo_url'] ?? userData?['avatar_url'];
    final bio = userData?['bio'] as String?;
    final subjects = (userData?['subjects'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherProfileScreen(
              teacherId: teacher['user_id'] ?? '',
              teacherName: name,
              teacherPhoto: avatarUrl,
              bio: bio,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getGlassColor(context, opacity: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Image.network(
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.network(
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Subjects
            if (subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  subjects.join('، '),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryPurple.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            if (bio != null && bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
