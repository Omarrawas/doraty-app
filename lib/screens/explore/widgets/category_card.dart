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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 4),
          width: 140, 
          height: 140,
          decoration: BoxDecoration(
            color: isSelected
                ? itemColor.withOpacity(isDark ? 0.35 : 0.15)
                : (isDark 
                    ? AppColors.getSurfaceColor(context) 
                    : Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? itemColor
                  : (isDark ? Colors.white12 : Colors.grey.shade200.withOpacity(0.5)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: itemColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: category.iconUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    color: isSelected ? null : itemColor, 
                    colorBlendMode: isSelected ? null : BlendMode.srcIn,
                    errorWidget: (context, url, err) =>
                        Icon(Icons.category_rounded, color: itemColor, size: 48),
                  ),
                )
              else
                Icon(Icons.category_rounded, color: itemColor, size: 48),
  
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
                    color: isDark ? Colors.white : const Color(0xFF2D2D3A),
                    height: 1.2,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
