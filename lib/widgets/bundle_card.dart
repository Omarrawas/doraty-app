import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/bundle.dart';
import '../screens/packages/package_screen.dart';
import '../core/localization/locale_provider.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';

class BundleCard extends StatefulWidget {
  final Bundle bundle;
  final String? heroTag;

  const BundleCard({
    super.key,
    required this.bundle,
    this.heroTag,
  });

  @override
  State<BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends State<BundleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        final bundleToPush = widget.bundle;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PackageScreen(
              packageTitle: bundleToPush.title,
              courses: bundleToPush.courses,
              bundle: bundleToPush,
            ),
          ),
        );
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 280,
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Background Image
                Hero(
                  tag: widget.heroTag ?? 'bundle_${widget.bundle.id}',
                  child: CachedNetworkImage(
                    imageUrl: widget.bundle.imageUrl ?? '',
                    height: double.infinity,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.getMutedTextColor(context),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      child: Icon(Icons.collections_bookmark,
                          color: AppColors.getTextColor(context).withOpacity(0.24), size: 40),
                    ),
                  ),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.primaryPurple.withOpacity(0.4),
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppStrings.get('bundle_badge', locale),
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // Title
                      Text(
                        widget.bundle.title,
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Course Count
                      Row(
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              color: AppColors.getTextColor(context).withOpacity(0.70), size: 14),
                          SizedBox(width: 4),
                          Text(
                            '${widget.bundle.courses.length} ${AppStrings.get('courses_count', locale)}',
                            style: TextStyle(
                              color: AppColors.getTextColor(context).withOpacity(0.70),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Pricing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.bundle.hasDiscount)
                                Text(
                                  widget.bundle.getOriginalPrice(locale),
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context).withOpacity(0.54),
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                widget.bundle.getFormattedPrice(locale),
                                style: TextStyle(
                                  color: widget.bundle.hasDiscount
                                      ? Colors.greenAccent
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Arrow button component (glassmorphism style like CourseCard)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.getMutedTextColor(context),
                            ),
                            child: Icon(Icons.arrow_forward,
                                color: AppColors.getTextColor(context), size: 16),
                          ),
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
    );
  }
}
