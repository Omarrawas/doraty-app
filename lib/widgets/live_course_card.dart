import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/course.dart';
import '../core/theme/app_colors.dart';

class LiveCourseCard extends StatefulWidget {
  final Course course;

  const LiveCourseCard({super.key, required this.course});

  @override
  State<LiveCourseCard> createState() => _LiveCourseCardState();
}

class _LiveCourseCardState extends State<LiveCourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final bool isLive = course.isLive;
    final Color badgeColor = isLive ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6);
    final String badgeLabel = isLive ? 'بث مباشر' : 'حضوري';
    final IconData badgeIcon = isLive ? Icons.live_tv_rounded : Icons.location_on_rounded;

    return GestureDetector(
      onTap: () {
        final identifier = course.slug.isNotEmpty ? course.slug : course.id;
        context.push('/course/$identifier');
      },
      child: Container(
        width: 240,
        margin: const EdgeInsetsDirectional.only(end: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeColor.withOpacity(0.35),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getGlassColor(context, opacity: 0.18),
              AppColors.getGlassColor(context, opacity: 0.06),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: course.imageUrl ?? '',
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 130,
                      color: badgeColor.withOpacity(0.15),
                      child: Icon(badgeIcon, color: badgeColor, size: 40),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _pulseAnim.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                badgeLabel,
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
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 12,
                          color: AppColors.getTextColor(context, secondary: true)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          course.instructorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextColor(context, secondary: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        course.price > 0
                            ? '${course.price.toStringAsFixed(0)} ${course.currency}'
                            : 'مجاني',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: badgeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          'سجّل الآن',
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
