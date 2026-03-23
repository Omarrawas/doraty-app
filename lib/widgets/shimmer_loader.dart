import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerLoader.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  });

  const ShimmerLoader.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? Colors.white.withOpacity(0.15)
          : AppColors.primaryPurple.withOpacity(0.08),
      highlightColor: isDark
          ? Colors.white.withOpacity(0.35)
          : AppColors.primaryBlue.withOpacity(0.18),
      period: const Duration(seconds: 2),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.primaryPurple.withOpacity(0.06),
          shape: shapeBorder,
        ),
      ),
    );
  }
}

class CourseCardShimmer extends StatelessWidget {
  const CourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : AppColors.primaryPurple.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : AppColors.primaryPurple.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            ShimmerLoader.rectangular(
              height: 100,
              width: 100,
              shapeBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerLoader.rectangular(height: 20, width: 150),
                  SizedBox(height: 8),
                  ShimmerLoader.rectangular(height: 12, width: 100),
                  SizedBox(height: 12),
                  _RowShimmer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowShimmer extends StatelessWidget {
  const _RowShimmer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShimmerLoader.rectangular(height: 16, width: 60),
        _InnerRowShimmer(),
      ],
    );
  }
}

class _InnerRowShimmer extends StatelessWidget {
  const _InnerRowShimmer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerLoader.rectangular(height: 12, width: 40),
        SizedBox(width: 4),
        ShimmerLoader.circular(height: 16, width: 16),
      ],
    );
  }
}
