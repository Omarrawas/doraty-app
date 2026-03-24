import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../core/theme/app_colors.dart';
import '../../screens/courses/course_details_screen.dart';

class CoursePreviewModal extends StatelessWidget {
  final Course course;

  CoursePreviewModal({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getTextColor(context).withOpacity(0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 24),

          // Course Info Row
          Row(
            children: [
              // Course Thumbnail (Placeholder or Real)
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: course.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(course.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppColors.getTextColor(context).withOpacity(0.10),
                ),
                child: course.imageUrl == null
                    ? Icon(Icons.school, color: AppColors.getTextColor(context).withOpacity(0.24), size: 40)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: AppColors.getTextColor(context).withOpacity(0.54), size: 14),
                        SizedBox(width: 4),
                        Text(
                          course.durationHours ?? '0س 55د', // Placeholder if null
                          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 13),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.star, color: AppColors.secondaryGold, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '${course.rating}',
                          style: TextStyle(color: AppColors.getTextColor(context), fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: course.instructorPhoto != null
                              ? NetworkImage(course.instructorPhoto!)
                              : null,
                          child: course.instructorPhoto == null
                              ? Icon(Icons.person, size: 14)
                              : null,
                        ),
                        SizedBox(width: 8),
                        Text(
                          course.instructorName,
                          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 32),

          // Action Button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseDetailsScreen(course: course),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill, size: 24),
                SizedBox(width: 12),
                Text(
                  'ابدأ الدورة الآن',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
