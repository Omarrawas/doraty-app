import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/category_model.dart';
import '../../../core/theme/app_colors.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  final bool isSelected;
  final EdgeInsetsGeometry? margin;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.isSelected = false,
    this.margin,
  });

  Color get _color {
    final colors = [
      Color(0xFFE55A7E), // Pink
      Color(0xFF5A8DEE), // Blue
      Color(0xFFF18671), // Orange-Red
      Color(0xFF14B3C5), // Cyan
      Color(0xFF4CAF50), // Green
      Color(0xFFF09A36), // Yellow
    ];
    int hash = category.id.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = _color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.only(right: 12),
        width: 130, // Fixed default width suitable for a rectangular card
        decoration: BoxDecoration(
          color: isSelected
              ? itemColor.withOpacity(isDark ? 0.3 : 0.1)
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? itemColor
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: category.iconUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  color: itemColor, // Tint the image with our matched color if it's an outline, otherwise it falls back nicely
                  colorBlendMode: BlendMode.srcIn,
                  errorWidget: (context, url, err) =>
                      Icon(Icons.category_rounded, color: itemColor, size: 36),
                ),
              )
            else
              Icon(Icons.category_rounded, color: itemColor, size: 36),

            SizedBox(height: 12),

            // Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  // Use matched item color for text in light mode as requested in the mockup, white in dark mode.
                  color: isDark ? Colors.white : itemColor.withOpacity(0.9),
                  height: 1.2,
                  fontFamily: 'Cairo', // Ensure standard smooth font
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
