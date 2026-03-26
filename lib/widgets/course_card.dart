import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../screens/courses/course_details_screen.dart';
import '../core/services/auth_service.dart';
import '../core/localization/locale_provider.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/string_utils.dart';
import '../core/theme/app_colors.dart';

import '../core/services/database_service.dart';

class CourseCard extends StatefulWidget {
  final Course course;
  final String? heroTag;
  final double? progress;
  final bool isHorizontal;

  const CourseCard({
    super.key,
    required this.course,
    this.heroTag,
    this.progress,
    this.isHorizontal = false,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isFavorite = false;
  bool _hasCourseAccess = false;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _hasCourseAccess = widget.progress != null || widget.course.isEnrolled;
    _checkFavoriteStatus();
    _checkCourseAccess();
  }

  Future<void> _checkCourseAccess() async {
    if (_hasCourseAccess) return;
    try {
      final hasAccess = await _databaseService.hasCourseAccess(
        widget.course.id,
        forceRefresh: true,
      );
      if (mounted) setState(() => _hasCourseAccess = hasAccess);
    } catch (e) {
      debugPrint('Error checking course access: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final status = await _databaseService.isFavorite(widget.course.id);
      if (mounted) setState(() => _isFavorite = status);
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }
    try {
      final newStatus =
          await _databaseService.toggleFavorite(widget.course.id, !_isFavorite);
      if (mounted) {
        setState(() => _isFavorite = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite
                ? AppStrings.get('added_to_favorites',
                    Provider.of<LocaleProvider>(context, listen: false).locale)
                : AppStrings.get(
                    'removed_from_favorites',
                    Provider.of<LocaleProvider>(context, listen: false)
                        .locale)),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: () {
              final courseToPush = widget.course;
              final heroTagToPush = widget.heroTag;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseDetailsScreen(
                    course: courseToPush,
                    heroTag: heroTagToPush,
                  ),
                ),
              );
            },
            child: widget.isHorizontal
                ? _buildHorizontalLayout(context, locale, isDark)
                : _buildVerticalLayout(context, locale, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context, String locale, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
                // --- 1. Top Image with Badges ---
                Stack(
                  children: [
                    Hero(
                      tag: widget.heroTag ?? 'course_image_${widget.course.id}',
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: widget.course.imageUrl != null &&
                                  widget.course.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.course.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.withOpacity(0.1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryPurple),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.grey.withOpacity(0.1),
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey, size: 30),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.withOpacity(0.1),
                                  child: Icon(Icons.image_not_supported,
                                      color: Colors.grey),
                                ),
                        ),
                      ),
                    ),
                    // Wishlist Icon (Top Right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isFavorite ? Colors.redAccent : Colors.white,
                          size: 26,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                    // "New" Badge (Top Left)
                    if (widget.course.isNew)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppStrings.get('new_badge', locale) == 'new_badge'
                                ? 'جديد'
                                : AppStrings.get('new_badge', locale),
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Duration Badge (Bottom Right matching image layout)
                    if (widget.course.durationHours != null &&
                        widget.course.durationHours!.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                // Quick logic to extract just hours and minutes if easily parseable, or simply show the string
                                widget.course.durationHours!
                                    .replaceAll('ساعات', 'س')
                                    .replaceAll('دقائق', 'د'),
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // --- 2. Content ---
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title and Instructor
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.course.getLocalizedTitle(locale),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                                height: 1.3,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'تقديم ${StringUtils.cleanTeacherName(widget.course.getLocalizedInstructorName(locale))}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextColor(context,
                                    secondary: true),
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        // Prices and Button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasCourseAccess) ...[
                              // Progress
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppStrings.get('progress_label', locale),
                                    style: TextStyle(
                                        color: AppColors.getTextColor(context,
                                            secondary: true),
                                        fontSize: 11),
                                  ),
                                  Text(
                                    '${((widget.progress ?? 0) * 100).toInt()}%',
                                    style: TextStyle(
                                        color: AppColors.getTextColor(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widget.progress ?? 0,
                                  backgroundColor: AppColors.getGlassColor(
                                      context,
                                      opacity: 0.1),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.greenAccent),
                                  minHeight: 4,
                                ),
                              ),
                              SizedBox(height: 12),
                            ] else if (widget.course.price > 0) ...[
                              // Pricing
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.course.hasDiscount) ...[
                                    Text(
                                      widget.course.getFormattedPrice(locale),
                                      style: TextStyle(
                                        color: AppColors.getTextColor(context,
                                                secondary: true)
                                            .withOpacity(0.5),
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                  ],
                                  Text(
                                    widget.course.getLocalizedPrice(locale),
                                    style: TextStyle(
                                      color: AppColors.getTextColor(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                            ],

                            // Independent Subscribe Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(
                                      0xFF434775), // Exact purple-blue color from the image
                                  foregroundColor: Colors.white,
                                  padding:
                                      EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CourseDetailsScreen(
                                        course: widget.course,
                                        heroTag: widget.heroTag,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  _hasCourseAccess ? 'أكمل مشاهدة' : 'اشترك',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, String locale, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. Top Image with Badges ---
        SizedBox(
          width: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: widget.heroTag ?? 'course_image_${widget.course.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadiusDirectional.horizontal(
                      start: Radius.circular(16)),
                  child: widget.course.imageUrl != null &&
                          widget.course.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.course.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.withOpacity(0.1),
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryPurple),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.withOpacity(0.1),
                            child: Icon(Icons.broken_image,
                                color: Colors.grey, size: 30),
                          ),
                        )
                      : Container(
                          color: Colors.grey.withOpacity(0.1),
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
                ),
              ),
              // Wishlist Icon (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? Colors.redAccent : Colors.white,
                    size: 22,
                    shadows: [
                      Shadow(color: Colors.black45, blurRadius: 6)
                    ],
                  ),
                ),
              ),
              // "New" Badge (Top Left)
              if (widget.course.isNew)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppStrings.get('new_badge', locale) == 'new_badge'
                          ? 'جديد'
                          : AppStrings.get('new_badge', locale),
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Duration Badge (Bottom Right matching image layout)
              if (widget.course.durationHours != null &&
                  widget.course.durationHours!.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.course.durationHours!
                              .replaceAll('ساعات', 'س')
                              .replaceAll('دقائق', 'د'),
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // --- 2. Content ---
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  widget.course.getLocalizedTitle(locale),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                    height: 1.3,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                
                // Pricing or Progress
                if (_hasCourseAccess) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.get('progress_label', locale),
                        style: TextStyle(
                            color: AppColors.getTextColor(context,
                                secondary: true),
                            fontSize: 10),
                      ),
                      Text(
                        '${((widget.progress ?? 0) * 100).toInt()}%',
                        style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.progress ?? 0,
                      backgroundColor:
                          AppColors.getGlassColor(context, opacity: 0.1),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      minHeight: 3,
                    ),
                  ),
                  SizedBox(height: 6),
                ] else if (widget.course.price > 0) ...[
                  Row(
                    children: [
                      Text(
                        widget.course.getLocalizedPrice(locale),
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.course.hasDiscount) ...[
                        SizedBox(width: 8),
                        Text(
                          widget.course.getFormattedPrice(locale),
                          style: TextStyle(
                            color: AppColors.getTextColor(context,
                                    secondary: true)
                                .withOpacity(0.5),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 6),
                ],
                
                // Instructor
                Text(
                  'تقديم ${StringUtils.cleanTeacherName(widget.course.getLocalizedInstructorName(locale))}',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextColor(context, secondary: true),
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLoginRequiredDialog() {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(
          AppStrings.get('login_required_title', locale),
          style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        content: Text(
          AppStrings.get('login_required_desc', locale),
          style: TextStyle(
              color: AppColors.getTextColor(context, secondary: true), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('cancel', locale),
                style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('login_title', locale),
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
