import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../models/review.dart';
import 'add_review_screen.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_utils.dart';

class ReviewsListScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const ReviewsListScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  final String _currentUserId = SupabaseService.instance.currentUserId ?? '';

  bool _isLoading = true;
  late CourseRating _courseRating;
  late List<Review> _reviews;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final reviewsData = await DatabaseService().getReviews(widget.courseId);

      setState(() {
        _reviews = reviewsData.map((data) => Review.fromJson(data)).toList();
        _calculateRating();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _reviews = [];
        _courseRating = CourseRating(
          averageRating: 0,
          totalReviews: 0,
          ratingDistribution: {},
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  void _calculateRating() {
    if (_reviews.isEmpty) {
      _courseRating = CourseRating(
        averageRating: 0,
        totalReviews: 0,
        ratingDistribution: {},
      );
      return;
    }

    double totalRating = 0;
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var review in _reviews) {
      totalRating += review.rating;
      int ratingInt = review.rating.round();
      if (ratingInt >= 1 && ratingInt <= 5) {
        distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      }
    }

    _courseRating = CourseRating(
      averageRating: totalRating / _reviews.length,
      totalReviews: _reviews.length,
      ratingDistribution: distribution,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overall Rating
                            _buildOverallRating(),

                            SizedBox(height: 24),

                            // Rating Distribution
                            _buildRatingDistribution(),

                            SizedBox(height: 24),

                            // Add Review Button
                            _buildAddReviewButton(),

                            SizedBox(height: 24),

                            // Reviews List
                            Text(
                              'التقييمات',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),

                            SizedBox(height: 16),

                            if (_reviews.isEmpty)
                              Center(
                                child: Text(
                                  'لا توجد تقييمات بعد',
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context, secondary: true),
                                  ),
                                ),
                              )
                            else
                              ..._reviews.map((review) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: _buildReviewCard(review),
                                );
                              }),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'التقييمات والمراجعات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildOverallRating() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Rating Number
              Column(
                children: [
                  Text(
                    _courseRating.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  RatingBarIndicator(
                    rating: _courseRating.averageRating,
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    itemCount: 5,
                    itemSize: 20,
                    direction: Axis.horizontal,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${_courseRating.totalReviews} تقييم',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingDistribution() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            children: List.generate(5, (index) {
              final stars = 5 - index;
              final percentage = _courseRating.getPercentageForRating(stars);
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '$stars',
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: AppColors.getTextColor(context, secondary: true),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildAddReviewButton() {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddReviewScreen(
                        courseId: widget.courseId,
                        courseName: widget.courseName,
                      ),
                    ),
                  );
                  if (result == true) {
                    // Refresh reviews
                    setState(() {
                      _fetchReviews();
                    });
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: AppColors.getTextColor(context)),
                      SizedBox(width: 8),
                      Text(
                        'أضف تقييمك',
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildReviewCard(Review review) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info
              Row(
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: review.userPhoto ?? '',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.getMutedTextColor(context),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.getMutedTextColor(context),
                        child: Icon(
                          Icons.person,
                          color: AppColors.getTextColor(context),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        Text(
                          _formatDate(review.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context, secondary: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  RatingBarIndicator(
                    rating: review.rating,
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    itemCount: 5,
                    itemSize: 16,
                    direction: Axis.horizontal,
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Comment
              Text(
                review.comment,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context),
                  height: 1.5,
                ),
              ),

              SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  _buildActionButton(
                    icon: review.isLikedBy(_currentUserId)
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    label: '${review.likesCount}',
                    onTap: () {},
                    isActive: review.isLikedBy(_currentUserId),
                  ),
                  SizedBox(width: 12),
                  _buildActionButton(
                    icon: review.isDislikedBy(_currentUserId)
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    label: '${review.dislikesCount}',
                    onTap: () {},
                    isActive: review.isDislikedBy(_currentUserId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppColors.getTextColor(context),
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
