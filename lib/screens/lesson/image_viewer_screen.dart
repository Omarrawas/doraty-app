import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/services/offline_storage_service.dart';
import '../../core/theme/app_colors.dart';

class ImageViewerScreen extends StatefulWidget {
  final String? localPath;
  final String? url;
  final String title;
  final bool isOffline;

  const ImageViewerScreen({
    super.key,
    this.localPath,
    this.url,
    required this.title,
    this.isOffline = false,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  Uint8List? _imageData;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isOffline && widget.localPath != null) {
      _loadOfflineImage();
    } else {
      _isLoading = false; // network image handled by Image.network
    }
  }

  Future<void> _loadOfflineImage() async {
    try {
      Uint8List decrypted;

      if (widget.localPath!.startsWith('hive://')) {
        // Handle Hive storage
        final parts = widget.localPath!.replaceFirst('hive://', '').split('/');
        if (parts.length < 2) throw Exception('Invalid hive path');
        
        final lessonId = parts[0];
        final fileName = parts[1];
        
        final encryptedData = await OfflineStorageService().getResource(lessonId, fileName);
        if (encryptedData == null) throw Exception('Resource not found in Hive');
        
        decrypted = encryptedData;
      } else {
        // Handle File storage
        if (kIsWeb) throw Exception('File access not supported on Web');
        final file = File(widget.localPath!);
        if (!await file.exists()) throw Exception('File not found');
        
        decrypted = await file.readAsBytes();
      }
      
      setState(() {
        _imageData = decrypted;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading offline image: $e');
      setState(() {
        _error = 'تعذر تحميل الصورة المشفرة';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: AppColors.primaryPurple)
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.white70))
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: widget.isOffline
                        ? Image.memory(
                            _imageData!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('خطأ في عرض الصورة', style: TextStyle(color: Colors.white70)),
                          )
                        : Image.network(
                            widget.url!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const CircularProgressIndicator(color: AppColors.primaryPurple);
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('خطأ في تحميل الصورة', style: TextStyle(color: Colors.white70)),
                          ),
                  ),
      ),
    );
  }
}
