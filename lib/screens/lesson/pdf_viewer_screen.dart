import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: IconThemeData(color: AppColors.getTextColor(context)),
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.url,
            key: _pdfViewerKey,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _isLoading = false;
              });
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              setState(() {
                _isLoading = false;
              });
              _showErrorDialog(context, details.error);
            },
            enableDoubleTapZooming: true,
            enableTextSelection: false,
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خطأ في التحميل'),
        content: Text('تعذر تحميل الملف. يرجى المحاولة مرة أخرى لاحقاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoading = true;
              });
            },
            child: Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

