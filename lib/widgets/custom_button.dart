import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final IconData? icon;
  final double? width;

  CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        gradient: type == ButtonType.primary ? AppColors.primaryGradient : null,
        color: type == ButtonType.secondary
            ? AppColors.cardBackground
            : type == ButtonType.outlined
                ? Colors.transparent
                : null,
        borderRadius: BorderRadius.circular(12),
        border: type == ButtonType.outlined
            ? Border.all(color: AppColors.primaryPurple, width: 2)
            : null,
        boxShadow: type == ButtonType.primary && onPressed != null
            ? AppColors.buttonShadow
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: _getTextColor(),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getTextColor(),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Color _getTextColor() {
    switch (type) {
      case ButtonType.primary:
        return Colors.white;
      case ButtonType.secondary:
        return AppColors.primaryPurple;
      case ButtonType.outlined:
        return AppColors.primaryPurple;
    }
  }
}

enum ButtonType {
  primary,
  secondary,
  outlined,
}
