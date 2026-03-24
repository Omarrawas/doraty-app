import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ProfessionalEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? retryText;

  ProfessionalEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search_off_rounded,
    this.onRetry,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getMutedTextColor(context),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.getMutedTextColor(context),
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextColor(context, secondary: true),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  retryText ?? 'إعادة المحاولة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
