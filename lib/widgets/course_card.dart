import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../screens/courses/course_details_screen.dart';
import '../core/localization/locale_provider.dart';
import '../core/constants/app_strings.dart';
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
                        // Level Badge
                        if (widget.course.level != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (widget.course.level == 'expert'
                                        ? Colors.redAccent
                                        : (widget.course.level == 'intermediate'
                                            ? Colors.orangeAccent
                                            : Colors.teal))
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppStrings.get(widget.course.level ?? 'beginner', locale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Duration Badge
                        if (widget.course.durationHours != null && widget.course.durationHours!.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      color: Colors.white, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.course.durationHours} ${AppStrings.get('hours_short', locale)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Line 1: Instructor & Rating ---
                          Row(
                            children: [
                              _buildSimpleAvatar(),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${AppStrings.get('by_prefix', locale)} ${StringUtils.cleanTeacherName(widget.course.getLocalizedInstructorName(locale))}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < widget.course.rating.floor()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // --- Line 2: Course Title ---
                          Text(
                            widget.course.getLocalizedTitle(locale),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),

                          // --- Line 3: Small Categories & Tags ---
                          if (widget.course.categories.isNotEmpty || widget.course.tags.isNotEmpty)
                            Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                ...widget.course.categories.take(1).map((cat) => _buildMiniTag(
                                    cat, 
                                    Colors.blue.withOpacity(0.1), 
                                    Colors.blueAccent)),
                                ...widget.course.tags.take(1).map((tag) => _buildMiniTag(
                                    '#${AppStrings.get(tag, locale)}', 
                                    Colors.purple.withOpacity(0.1), 
                                    Colors.purpleAccent)),
                              ],
                            ),

                          const SizedBox(height: 6),
                          
                          // --- Line 4: Pricing & Progress Row ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Progress/Students
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.course.studentsCount} ${AppStrings.get('students_count_label', locale)}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(1),
                                      child: LinearProgressIndicator(
                                        value: (widget.course.studentsCount / 100).clamp(0.01, 1.0),
                                        backgroundColor: Colors.white10,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent.withOpacity(0.4)),
                                        minHeight: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Prices
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.course.hasDiscount)
                                    Text(
                                      widget.course.getFormattedPrice(locale),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 8,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    widget.course.getLocalizedPrice(locale),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          if (widget.showEnrollButton)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                                color: Colors.white.withOpacity(0.04),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppStrings.get('view_details', locale),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.arrow_forward_ios, size: 6, color: Colors.white),
                                  ],
                                ),
                              ),
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

  Widget _buildMiniTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

