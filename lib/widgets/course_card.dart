import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../screens/courses/course_details_screen.dart';
import '../screens/auth/login_screen.dart';
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

  const CourseCard({
    super.key,
    required this.course,
    this.heroTag,
    this.progress,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isFavorite = false;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _checkFavoriteStatus();
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
      final newStatus = await _databaseService.toggleFavorite(widget.course.id, !_isFavorite);
      if (mounted) {
        setState(() => _isFavorite = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? AppStrings.get('added_to_favorites', Provider.of<LocaleProvider>(context, listen: false).locale) : AppStrings.get('removed_from_favorites', Provider.of<LocaleProvider>(context, listen: false).locale)),
            duration: const Duration(seconds: 1),
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

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha((0.25 * 255).round()),
                  Colors.white.withAlpha((0.15 * 255).round()),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha((0.3 * 255).round()),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTapDown: (_) => _controller.forward(),
                onTapUp: (_) => _controller.reverse(),
                onTapCancel: () => _controller.reverse(),
                onTap: () {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 1. Top Image with Badge ---
                    Stack(
                      children: [
                        Hero(
                          tag: widget.heroTag ?? 'course_image_${widget.course.id}',
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              child: widget.course.imageUrl != null &&
                                      widget.course.imageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: widget.course.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.white10,
                                          child: const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.white10,
                                          child: const Icon(Icons.broken_image,
                                              color: Colors.white24, size: 30),
                                        ),
                                      )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.white30),
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
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? Colors.redAccent : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        // Duration Badge (Bottom Right)
                        if (widget.course.durationHours != null && widget.course.durationHours!.isNotEmpty)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.course.durationHours} ${AppStrings.get('hours_short', locale)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                AppStrings.get('new_badge', locale) == 'new_badge' ? 'جديد' : AppStrings.get('new_badge', locale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Line 1: Course Title ---
                          Text(
                            widget.course.getLocalizedTitle(locale),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // --- Line 2: Instructor ---
                          Row(
                            children: [
                              _buildSimpleAvatar(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${AppStrings.get('by_prefix', locale)} ${StringUtils.cleanTeacherName(widget.course.getLocalizedInstructorName(locale))}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // --- Line 3: Pricing and Progress/Subscribe Action ---
                          Row(
                            children: [
                              if (widget.progress != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(widget.progress! * 100).toInt()}% ${AppStrings.get('completed', locale)}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: widget.progress,
                                          backgroundColor: Colors.white10,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (widget.course.hasDiscount)
                                        Text(
                                          widget.course.getFormattedPrice(locale),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.3),
                                            fontSize: 10,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        widget.course.getLocalizedPrice(locale),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryPurple.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    AppStrings.get('buy_now', locale),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleAvatar() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipOval(
        child: widget.course.instructorPhoto != null &&
                widget.course.instructorPhoto!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.course.instructorPhoto!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.person, size: 14, color: Colors.white30),
              )
            : const Icon(Icons.person, size: 14, color: Colors.white30),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(
          AppStrings.get('login_required_title', locale),
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        content: Text(
          AppStrings.get('login_required_desc', locale),
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('cancel', locale), style: const TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('login_title', locale), style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

