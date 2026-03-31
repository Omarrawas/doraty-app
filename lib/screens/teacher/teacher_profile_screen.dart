import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/database_service.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';
import '../../core/utils/string_utils.dart';
import '../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../models/bundle.dart';
import '../../widgets/bundle_card.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? teacherPhoto;
  final String? bio;

  const TeacherProfileScreen({
    super.key,
    required this.teacherId,
    this.teacherName = '',
    this.teacherPhoto,
    this.bio,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _teacherCourses = [];
  List<Bundle> _teacherBundles = [];
  bool _isLoading = true;

  String? _teacherBio;
  String? _teacherPhoto;
  String _teacherName = '';
  String? _teacherPhone;
  Map<String, dynamic> _stats = {};
  late TabController _tabController;

  String _t(String key) {
    if (!mounted) return key;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _teacherName = StringUtils.cleanTeacherName(widget.teacherName);
    _teacherPhoto = widget.teacherPhoto;
    _teacherBio = widget.bio;
    _loadTeacherData();
    _loadTeacherCourses();
    _loadTeacherStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherData({bool forceRefresh = false}) async {
    try {
      final userData = await _databaseService.getUserById(widget.teacherId,
          forceRefresh: forceRefresh);
      if (mounted && userData != null) {
        setState(() {
          _teacherName = StringUtils.cleanTeacherName(
              userData['full_name'] ?? userData['name'] ?? widget.teacherName);
          _teacherPhoto = userData['photo_url'] ??
              userData['avatar_url'] ??
              widget.teacherPhoto;
          _teacherBio = userData['bio'];
          _teacherPhone = userData['phone']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher data: $e');
    }
  }

  Future<void> _loadTeacherCourses({bool forceRefresh = false}) async {
    try {
      final coursesData =
          await _databaseService.getCoursesByTeacherId(widget.teacherId);
      final bundlesData =
          await _databaseService.getBundlesByTeacherId(widget.teacherId);
      if (mounted) {
        setState(() {
          _teacherCourses =
              coursesData.map((data) => Course.fromJson(data)).toList();
          _teacherBundles =
              bundlesData.map((data) => Bundle.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher courses/bundles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTeacherStats({bool forceRefresh = false}) async {
    try {
      final stats = await _databaseService.getTeacherStatistics(widget.teacherId,
          forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher stats: $e');
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadTeacherData(forceRefresh: true),
      _loadTeacherCourses(forceRefresh: true),
      _loadTeacherStats(forceRefresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    bool isRTL = Provider.of<LocaleProvider>(context).locale == 'ar';
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          color: AppColors.primaryPurple,
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // Header Section
                      SliverToBoxAdapter(
                        child: _buildHeader(context, isRTL),
                      ),
                      
                      // Tab Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: AppColors.primaryPurple,
                            indicatorWeight: 3,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white.withOpacity(0.5),
                            tabs: [
                              Tab(text: _t('home')),
                              Tab(text: _t('courses')),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      // Bio/About Section
                      _buildBioSection(isRTL),
                      
                      // Courses Section
                      _buildCoursesGrid(context),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isRTL) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 30),
      child: Column(
        children: [
          // Custom Back Button
          Align(
            alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Avatar
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: _teacherPhoto != null && _teacherPhoto!.isNotEmpty
                  ? (_teacherPhoto!.startsWith('data:')
                      ? Image.memory(
                          StringUtils.decodeBase64Image(_teacherPhoto!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.network(
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: _teacherPhoto!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.10)),
                          errorWidget: (context, url, error) => Image.network(
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                          ),
                        ))
                  : Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                    ),
            ),
          ),
          SizedBox(height: 16),
          
          // Name & Type
          Text(
            _teacherName,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            _t('trainer'),
            style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context, secondary: true), fontWeight: FontWeight.w500),
          ),
          
          if (_teacherPhone != null && _teacherPhone!.trim().isNotEmpty) ...[
            SizedBox(height: 16),
            InkWell(
              onTap: () async {
                String phone = _teacherPhone!.trim();
                // Syrian local numbers usually start with 09
                if (phone.startsWith('09')) {
                  phone = '963${phone.substring(1)}';
                }
                final uri = Uri.parse('whatsapp://send?phone=$phone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // Fallback to web link if WhatsApp client isn't installed
                  final webUri = Uri.parse('https://wa.me/$phone');
                  if (await canLaunchUrl(webUri)) {
                    await launchUrl(webUri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'تواصل معي', // Contact me
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          SizedBox(height: 24),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(
                _t('course'),
                _teacherCourses.length.toString(),
                Icons.library_books_outlined,
              ),
              SizedBox(width: 40),
              _buildStatItem(
                _t('students'),
                _formatNumber(_stats['total_users'] ?? 0),
                Icons.people_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k+';
    }
    return number.toString();
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context, secondary: true)),
        ),
      ],
    );
  }

  Widget _buildBioSection(bool isRTL) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _t('about_trainer'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              _teacherBio ?? _t('no_bio_available'),
              style: TextStyle(fontSize: 15, color: AppColors.getTextColor(context, secondary: true), height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesGrid(BuildContext context) {
    if (_teacherCourses.isEmpty && _teacherBundles.isEmpty) {
      return Center(
        child: Text(
          _t('no_courses_available'),
          style: TextStyle(
              color: AppColors.getTextColor(context).withOpacity(0.54)),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    double childAspectRatio = 2.4; // Matches horizontal card aspect ratio
    bool isSmallScreen = screenWidth <= 550;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.72;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.68;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    }

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(), // Let NestedScrollView in parent handle scrolling
      shrinkWrap: true,
      slivers: [
        if (_teacherCourses.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                _t('courses'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => CourseCard(
                  course: _teacherCourses[index],
                  isHorizontal: isSmallScreen,
                ),
                childCount: _teacherCourses.length,
              ),
            ),
          ),
        ],
        if (_teacherBundles.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Text(
                _t('bundles_label'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isSmallScreen ? 1 : crossAxisCount,
                childAspectRatio: isSmallScreen ? 2.0 : 1.4, // Making bundles less tall
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => BundleCard(
                  bundle: _teacherBundles[index],
                  heroTag: 'teacher_profile_bundle_${_teacherBundles[index].id}',
                ),
                childCount: _teacherBundles.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color(0xFF1E1E2C).withOpacity(0.9), // Match theme or use blurring
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
