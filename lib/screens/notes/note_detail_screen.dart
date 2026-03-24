import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/note.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;

  NoteDetailScreen({
    super.key,
    required this.note,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.note.isPinned;
  }

  void _togglePin() {
    setState(() {
      _isPinned = !_isPinned;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPinned ? 'تم تثبيت الملاحظة' : 'تم إلغاء التثبيت'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (context) => _buildDeleteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.note.title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Metadata
                      _buildMetadata(),

                      SizedBox(height: 24),

                      // Content
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: double.infinity,
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
                            child: Text(
                              widget.note.content,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.getTextColor(context),
                                height: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Tags
                      if (widget.note.tags.isNotEmpty) _buildTags(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ),
          ),
          Spacer(),
          // Pin Button
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: _isPinned ? Colors.amber : Colors.white,
                  ),
                  onPressed: _togglePin,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          // Delete Button
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteNote,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // Date
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                color: AppColors.getTextColor(context, secondary: true),
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                '${widget.note.updatedAt.day}/${widget.note.updatedAt.month}/${widget.note.updatedAt.year}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
        ),

        // Video Timestamp
        if (widget.note.videoTimestamp != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: AppColors.getTextColor(context),
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  widget.note.formattedTimestamp,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوسوم',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.note.tags.map((tag) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getMutedTextColor(context),
                ),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeleteDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.getMutedTextColor(context),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'حذف الملاحظة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'هل أنت متأكد من حذف هذه الملاحظة؟ لا يمكن التراجع عن هذا الإجراء.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.getMutedTextColor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'إلغاء',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم حذف الملاحظة'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'حذف',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
