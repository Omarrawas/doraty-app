import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/category_model.dart';
import '../../../core/theme/app_colors.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryPurple.withOpacity(0.2) 
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryPurple 
                : Colors.grey.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: category.iconUrl!,
                width: 40,
                height: 40,
                placeholder: (context, url) => const Icon(Icons.category, color: Colors.grey),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.grey),
              )
            else
              const Icon(Icons.school, size: 40, color: AppColors.primaryPurple),
            
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.normal : FontWeight.w500,
                  color: isSelected ? AppColors.primaryPurple : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
