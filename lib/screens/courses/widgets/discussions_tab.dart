import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/services/database_service.dart';
import '../../../models/discussion.dart';

class DiscussionsTab extends StatefulWidget {
  final String courseId;

  const DiscussionsTab({super.key, required this.courseId});

  @override
  State<DiscussionsTab> createState() => _DiscussionsTabState();
}

class _DiscussionsTabState extends State<DiscussionsTab> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Map<String, dynamic>>> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = _db.getDiscussionThreads(widget.courseId);
  }

  void _refreshThreads() {
    setState(() {
      _threadsFuture = _db.getDiscussionThreads(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCreateActionButton(),
        FutureBuilder<List<Map<String, dynamic>>>(
            future: _threadsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ في تحميل المناقشات',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                );
              }

              final threadsData = snapshot.data ?? [];
              if (threadsData.isEmpty) {
                return _buildEmptyState();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: threadsData.map((data) {
                    final thread = DiscussionThread.fromJson(data);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildThreadCard(thread),
                    );
                  }).toList(),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCreateActionButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: () => _showCreateThreadDialog(),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_comment_rounded, color: AppColors.primaryPurple),
              SizedBox(width: 10),
              Text(
                'بدء مناقشة جديدة',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(DiscussionThread thread) {
    return InkWell(
      onTap: () {
        // Navigate to thread detail
      },
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: thread.userAvatar != null
                          ? NetworkImage(thread.userAvatar!)
                          : null,
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                      child: thread.userAvatar == null
                          ? const Icon(Icons.person, size: 20, color: Colors.white30)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatDate(thread.createdAt),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  thread.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  thread.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '${thread.repliesCount} ردود',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'عرض التفاصيل',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: AppColors.primaryPurple),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined,
              size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          Text(
            'لا يوجد مناقشات بعد في هذا الكورس',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'كن أول من يطرح سؤالاً أو يشارك فكرة!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateThreadDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'موضوع جديد',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'عنوان الموضوع',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: contentController,
              textAlign: TextAlign.right,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك أو فكرتك هنا...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                try {
                  await _db.createDiscussionThread(
                    courseId: widget.courseId,
                    title: titleController.text,
                    content: contentController.text,
                  );
                  if (mounted) {
                    navigator.pop();
                    _refreshThreads();
                  }
                } catch (e) {
                  // Handle error
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('نشر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple format for now
    return '${date.day}/${date.month}';
  }
}
