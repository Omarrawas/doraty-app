import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ImageViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const ImageViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: IconThemeData(color: AppColors.getTextColor(context)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
            },
            errorBuilder: (context, error, stackTrace) =>
                Text('خطأ في تحميل الصورة', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70))),
          ),
        ),
      ),
    );
  }
}

