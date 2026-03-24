import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/bookmark.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';

class BookmarksWidget extends StatefulWidget {
  final String lessonId;
  final YoutubePlayerController? youtubeController;

  const BookmarksWidget({
    super.key,
    required this.lessonId,
    this.youtubeController,
  });

  @override
  State<BookmarksWidget> createState() => _BookmarksWidgetState();
}

class _BookmarksWidgetState extends State<BookmarksWidget> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  List<Bookmark> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _databaseService.getBookmarks(widget.lessonId);
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks.map((e) => Bookmark.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addBookmark() async {
    final timestamp = widget.youtubeController?.value.position.inSeconds ?? 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'إضافة علامة مرجعية',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'العنوان',
                labelStyle: TextStyle(color: AppColors.getTextColor(context)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple),
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: TextStyle(color: AppColors.getTextColor(context)),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                labelStyle: TextStyle(color: AppColors.getTextColor(context)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'الموضع: ${_formatTimestamp(timestamp)}',
              style: TextStyle(
                color: AppColors.getTextColor(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.trim().isEmpty) return;

              try {
                await _databaseService.saveBookmark(
                  lessonId: widget.lessonId,
                  timestamp: timestamp,
                  title: _titleController.text.trim(),
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                );

                if (!context.mounted) return;

                _titleController.clear();
                _noteController.clear();

                Navigator.pop(context);
                await _loadBookmarks();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تمت إضافة العلامة المرجعية')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            child: Text(
              'إضافة',
              style: TextStyle(color: AppColors.getTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBookmark(String bookmarkId) async {
    try {
      await _databaseService.deleteBookmark(bookmarkId);
      await _loadBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف العلامة المرجعية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  void _jumpToBookmark(int timestamp) {
    if (widget.youtubeController != null) {
      widget.youtubeController!.seekTo(Duration(seconds: timestamp));
    }
  }

  String _formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    color: AppColors.getTextColor(context),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'العلامات المرجعية',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryPurple,
                          AppColors.primaryBlue,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
                      onPressed: _addBookmark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
                )
              else if (_bookmarks.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          color: AppColors.getMutedTextColor(context),
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد علامات مرجعية بعد',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._bookmarks.map((bookmark) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.getMutedTextColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _jumpToBookmark(bookmark.timestamp),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bookmark.formattedTimestamp,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bookmark.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.getTextColor(context),
                                      ),
                                    ),
                                    if (bookmark.note != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        bookmark.note!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.getTextColor(context),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _deleteBookmark(bookmark.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
