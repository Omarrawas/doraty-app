import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/database_service.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';
import '../../core/utils/string_utils.dart';
import '../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? teacherPhoto;
  final String? bio;

  const TeacherProfileScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.teacherPhoto,
    this.bio,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Course> _teacherCourses = [];
  bool _isLoading = true;

  // Teacher data loaded from database
  String? _teacherBio;
  String? _teacherPhoto;
  String _teacherName = '';
  Map<String, dynamic> _stats = {};
  late TabController _tabController;

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
      if (mounted) {
        setState(() {
          _teacherCourses =
              coursesData.map((data) => Course.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher courses: $e');
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
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                              Tab(text: isRTL ? 'الرئيسية' : 'Home'),
                              Tab(text: isRTL ? 'الدورات' : 'Courses'),
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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: _teacherPhoto != null && _teacherPhoto!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _teacherPhoto!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white10),
                      errorWidget: (context, url, error) => Image.network(
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                      ),
                    )
                  : Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_teacherName)}&background=random&color=fff&size=200',
                    ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Name & Type
          Text(
            _teacherName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isRTL ? 'مدرب' : 'Trainer',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500),
          ),
          
          const SizedBox(height: 24),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(
                isRTL ? 'دورة' : 'Courses',
                _teacherCourses.length.toString(),
                Icons.library_books_outlined,
              ),
              const SizedBox(width: 40),
              _buildStatItem(
                isRTL ? 'طالب' : 'Students',
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
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _buildBioSection(bool isRTL) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isRTL ? 'نبذة عن المدرب' : 'About the Trainer',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _teacherBio ?? (isRTL ? 'لا توجد نبذة متاحة حالياً.' : 'No bio available at the moment.'),
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.6),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesGrid(BuildContext context) {
    if (_teacherCourses.isEmpty) {
      return Center(
        child: Text(
          Provider.of<LocaleProvider>(context).locale == 'ar' ? 'لا توجد دورات متاحة' : 'No courses available',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;
    final double childAspectRatio = screenWidth > 600 ? 0.75 : 0.68;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: _teacherCourses.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemBuilder: (context, index) {
        return CourseCard(course: _teacherCourses[index]);
      },
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
      color: const Color(0xFF1E1E2C).withOpacity(0.9), // Match theme or use blurring
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
