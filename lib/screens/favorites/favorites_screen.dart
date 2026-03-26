import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _error;

  late AnimationController _emptyAnimController;
  late Animation<double> _emptyFadeAnim;

  @override
  void initState() {
    super.initState();
    _emptyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _emptyFadeAnim = CurvedAnimation(
      parent: _emptyAnimController,
      curve: Curves.easeOut,
    );
    _loadFavorites();
  }

  @override
  void dispose() {
    _emptyAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _db.getFavoriteCourses();
      final courses = data.map((json) => Course.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
        if (courses.isEmpty) _emptyAnimController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFromFavorites(Course course, int index) async {
    try {
      setState(() => _courses.removeAt(index));
      await _db.toggleFavorite(course.id, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف الدورة من المفضلة'),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () async {
                await _db.toggleFavorite(course.id, true);
                _loadFavorites();
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        if (_courses.isEmpty) _emptyAnimController.forward();
      }
    } catch (e) {
      // Re-insert if failed
      setState(() => _courses.insert(index, course));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isRtl = locale == 'ar';

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                        color: AppColors.getTextColor(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'مفضلتي',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    // Badge count
                    if (!_isLoading && _courses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_courses.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),

              // ─── Body ───
              Expanded(
                child: _isLoading
                    ? _buildLoadingSkeleton()
                    : _error != null
                        ? _buildError()
                        : _courses.isEmpty
                            ? _buildEmpty()
                            : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppColors.primaryPurple,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return Dismissible(
            key: Key(course.id),
            direction: DismissDirection.endToStart,
            background: _buildDismissBackground(),
            confirmDismiss: (_) async {
              return await _showConfirmDialog(course.title);
            },
            onDismissed: (_) => _removeFromFavorites(course, index),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: 200,
                child: CourseCard(
                  course: course,
                  heroTag: 'fav_${course.id}_$index',
                  isHorizontal: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite_border_rounded, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text('حذف', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String courseTitle) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إزالة من المفضلة',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل تريد إزالة "$courseTitle" من قائمة مفضلتك؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getTextColor(context, secondary: true),
            fontFamily: 'Cairo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إزالة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return FadeTransition(
      opacity: _emptyFadeAnim,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryPurple.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                size: 64,
                color: AppColors.primaryPurple.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'قائمتك فارغة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم تضف أي دورة للمفضلة بعد\nاضغط على ❤️ في أي دورة لإضافتها هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextColor(context, secondary: true),
                height: 1.6,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.explore_outlined, color: AppColors.primaryPurple),
              label: Text(
                'استعرض الدورات',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Image Skeleton
                Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.getMutedTextColor(context),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                // Content skeleton
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonLine(0.8),
                        const SizedBox(height: 8),
                        _skeletonLine(0.5),
                        const SizedBox(height: 16),
                        _skeletonLine(0.4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _skeletonLine(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.getMutedTextColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 60, color: AppColors.getTextColor(context, secondary: true)),
          const SizedBox(height: 16),
          Text(
            'تعذّر تحميل المفضلة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
