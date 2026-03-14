import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/theme/app_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  final String? url;
  final String? localPath;
  final String title;
  final bool isOffline;

  const PdfViewerScreen({
    super.key,
    this.url,
    this.localPath,
    required this.title,
    this.isOffline = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;
  Uint8List? _offlineData;

  @override
  void initState() {
    super.initState();
    if (widget.isOffline && widget.localPath != null) {
      _loadOfflinePdf();
    }
  }

  Future<void> _loadOfflinePdf() async {
    try {
      Uint8List decrypted;

      if (widget.localPath!.startsWith('hive://')) {
        // Handle Hive storage (Web & Native fallback)
        final parts = widget.localPath!.replaceFirst('hive://', '').split('/');
        if (parts.length < 2) throw Exception('Invalid hive path');

        final lessonId = parts[0];
        final fileName = parts[1];

        final encryptedData =
            await OfflineStorageService().getResource(lessonId, fileName);
        if (encryptedData == null) {
          throw Exception('Resource not found in Hive');
        }

        decrypted = encryptedData;
      } else {
        // Handle File storage (Native only)
        if (kIsWeb) throw Exception('File access not supported on Web');
        final file = File(widget.localPath!);
        if (!await file.exists()) throw Exception('File not found: ${widget.localPath}');

        decrypted = await file.readAsBytes();
      }

      // Quick check if it's a valid PDF (should start with %PDF-)
      if (decrypted.length > 5) {
        final header = String.fromCharCodes(decrypted.sublist(0, 5));
        if (header != '%PDF-') {
          debugPrint('PDF Header mismatch: $header');
          throw Exception('Invalid PDF format after decryption');
        }
      }

      setState(() {
        _offlineData = decrypted;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading offline PDF: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الملف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (widget.isOffline)
            _offlineData != null
                ? SfPdfViewer.memory(
                    _offlineData!,
                    key: _pdfViewerKey,
                    enableTextSelection: false,
                  )
                : const Center(child: Text('تعذر تحميل الملف المشفر'))
          else
            SfPdfViewer.network(
              widget.url!,
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
            const Center(
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
        title: const Text('خطأ في التحميل'),
        content: const Text('تعذر تحميل الملف. يرجى المحاولة مرة أخرى لاحقاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoading = true;
              });
              // Re-triggering build will re-attempt network load
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
