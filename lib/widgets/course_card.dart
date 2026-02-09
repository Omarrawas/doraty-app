import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../screens/courses/course_details_screen.dart';
import '../core/localization/locale_provider.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/string_utils.dart';

class CourseCard extends StatefulWidget {
  final Course course;
  final String? heroTag;
  final bool showEnrollButton;

  const CourseCard({
    super.key,
    required this.course,
    this.heroTag,
    this.showEnrollButton = false,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Info (Now at the top)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course Title
                          Text(
                            widget.course.getLocalizedTitle(locale),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          Row(
                            children: [
                              if (widget.course.categories.isNotEmpty)
                                ...widget.course.categories
                                    .take(1)
                                    .map((cat) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPurple
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            cat,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white),
                                          ),
                                        )),
                              const Spacer(),
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < widget.course.rating.floor()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              _buildInstructorAvatar(),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  StringUtils.cleanTeacherName(widget.course
                                      .getLocalizedInstructorName(locale)),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.play_circle_outline,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.course.lessonsCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${widget.course.studentsCount} ${AppStrings.get('students_count_label', locale)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                              Text(
                                widget.course.getFormattedPrice(locale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      // Course Image (Now at the bottom)
                      Center(
                        child: Hero(
                          tag: widget.heroTag ??
                              'course_image_${widget.course.id}',
                          child: AspectRatio(
                            aspectRatio:
                                1.2, // Slightly taller for more presence
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
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
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: Colors.white10,
                                        child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white30),
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
                      ),

                      if (widget.showEnrollButton) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.visibility_outlined,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppStrings.get('view_details', locale),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInstructorAvatar() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: widget.course.instructorPhoto != null &&
                widget.course.instructorPhoto!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.course.instructorPhoto!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.white.withOpacity(0.5),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              )
            : Container(
                color: Colors.white.withOpacity(0.5),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 12,
                ),
              ),
      ),
    );
  }
}
