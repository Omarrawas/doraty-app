import 'package:flutter/material.dart';
import '../../models/offline_course.dart';
import '../../models/offline_lesson.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../lesson/pdf_viewer_screen.dart';
import '../lesson/image_viewer_screen.dart';

class CourseDownloadDetailsScreen extends StatefulWidget {
  final OfflineCourse course;

  const CourseDownloadDetailsScreen({super.key, required this.course});

  @override
  State<CourseDownloadDetailsScreen> createState() => _CourseDownloadDetailsScreenState();
}

class _CourseDownloadDetailsScreenState extends State<CourseDownloadDetailsScreen> {
  final OfflineStorageService _storage = OfflineStorageService();
  List<OfflineLesson> _lessonsWithResources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonDetails();
  }

  Future<void> _loadLessonDetails() async {
    try {
      final lessons = await _storage.getCourseLessons(widget.course.id);
      // Filter for lessons that actually have downloaded resources
      final filtered = lessons.where((l) => 
        (l.downloadedResources != null && l.downloadedResources!.isNotEmpty) || 
        l.videoPath != null
      ).toList();

      if (mounted) {
        setState(() {
          _lessonsWithResources = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading download details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openResource(String fileName, String localPath, String title) {
    final lowerCaseName = fileName.toLowerCase();
    
    if (lowerCaseName.endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            localPath: localPath,
            title: title,
            isOffline: true,
          ),
        ),
      );
    } else if (lowerCaseName.endsWith('.jpg') || 
               lowerCaseName.endsWith('.jpeg') || 
               lowerCaseName.endsWith('.png')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            localPath: localPath,
            title: title,
            isOffline: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الملف هذا غير مدعوم للعرض المباشر حالياً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.course.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _lessonsWithResources.isEmpty
                  ? _buildEmptyState()
                  : _buildLessonsList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد ملفات محملة لهذه الدورة',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lessonsWithResources.length,
      itemBuilder: (context, index) {
        final lesson = _lessonsWithResources[index];
        return _buildLessonCard(lesson);
      },
    );
  }

  Widget _buildLessonCard(OfflineLesson lesson) {
    final Map<String, String> resources = lesson.downloadedResources ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lesson.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...resources.entries.map((entry) => _buildResourceTile(entry.key, entry.value, lesson.title)),
          if (lesson.videoPath != null)
            _buildResourceTile('الفيديو التعليمي', lesson.videoPath!, lesson.title, isVideo: true),
        ],
      ),
    );
  }

  Widget _buildResourceTile(String fileName, String path, String lessonTitle, {bool isVideo = false}) {
    IconData iconData = Icons.insert_drive_file;
    Color iconColor = Colors.white70;

    if (isVideo) {
      iconData = Icons.play_circle_outline;
      iconColor = Colors.orangeAccent;
    } else {
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.pdf')) {
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.redAccent;
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
        iconData = Icons.image;
        iconColor = Colors.blueAccent;
      }
    }

    return ListTile(
      leading: Icon(iconData, color: iconColor),
      title: Text(
        fileName,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () {
        if (isVideo) {
          // Temporarily show message for video, or handle with video player if ready
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يمكنك مشاهدة الفيديو من صفحة الدرس مباشرة')),
          );
        } else {
          _openResource(fileName, path, fileName);
        }
      },
    );
  }
}
