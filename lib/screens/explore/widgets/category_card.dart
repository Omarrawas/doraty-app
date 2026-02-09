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
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? AppColors.primaryGradient
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              padding: EdgeInsets.all(isSelected ? 3 : 0),
              child: ClipOval(
                child: category.iconUrl != null && category.iconUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: category.iconUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.category,
                              color: Colors.white30, size: 24),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.error,
                              color: Colors.white30, size: 24),
                        ),
                      )
                    : Container(
                        color: Colors.white.withOpacity(0.1),
                        child: Icon(
                          Icons.school,
                          size: 30,
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryPurple,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 75,
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.normal : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
