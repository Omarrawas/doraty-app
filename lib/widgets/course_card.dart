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

  const CourseCard({
    super.key,
    required this.course,
    this.heroTag,
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
                  padding: const EdgeInsets.all(16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // Categories Tags
                          if (widget.course.categories.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: widget.course.categories
                                  .take(1) // Show only the primary category
                                  .map((cat) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPurple
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.1),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          cat,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),

                          const SizedBox(height: 10),

                          // Rating
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < widget.course.rating.floor()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Instructor & Students
                          Row(
                            children: [
                              _buildInstructorAvatar(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      StringUtils.cleanTeacherName(widget.course
                                          .getLocalizedInstructorName(locale)),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${widget.course.studentsCount} ${AppStrings.get('students_count_label', locale)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Lessons Count
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.course.lessonsCount} ${AppStrings.get('lessons_count_label', locale)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Course Image (Now at the bottom)
                      Center(
                        child: Hero(
                          tag: widget.heroTag ??
                              'course_image_${widget.course.id}',
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: AspectRatio(
                              aspectRatio:
                                  1.5, // Changed to 1.5 to be more flexible
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CachedNetworkImage(
                                  imageUrl: widget.course.imageUrl ?? '',
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
                                    child: const Icon(Icons.image_not_supported,
                                        color: Colors.white30),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.course.instructorPhoto ?? '',
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => Container(
            color: Colors.white.withOpacity(0.5),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }
}
