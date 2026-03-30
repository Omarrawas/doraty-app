import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/note.dart';
import 'add_note_screen.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late List<Note> _notes;
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  void _initializeMockData() {
    _notes = [
      Note(
        id: '1',
        userId: 'user123',
        courseId: '1',
        lessonId: '1',
        title: 'قوانين نيوتن للحركة',
        content: 'القانون الأول: الجسم الساكن يبقى ساكناً والجسم المتحرك يبقى متحركاً بسرعة ثابتة ما لم تؤثر عليه قوة خارجية.',
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
        tags: ['فيزياء', 'حركة'],
        isPinned: true,
        videoTimestamp: 125,
      ),
      Note(
        id: '2',
        userId: 'user123',
        courseId: '2',
        title: 'المعادلات التربيعية',
        content: 'الصيغة العامة: ax² + bx + c = 0\nالحل: x = (-b ± √(b²-4ac)) / 2a',
        createdAt: DateTime.now().subtract(Duration(days: 5)),
        updatedAt: DateTime.now().subtract(Duration(days: 3)),
        tags: ['رياضيات', 'معادلات'],
        isPinned: false,
      ),
      Note(
        id: '3',
        userId: 'user123',
        courseId: '3',
        lessonId: '3',
        title: 'الجدول الدوري',
        content: 'العناصر مرتبة حسب العدد الذري. المجموعات الرأسية لها خصائص متشابهة.',
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        updatedAt: DateTime.now().subtract(Duration(days: 1)),
        tags: ['كيمياء', 'عناصر'],
        isPinned: false,
        videoTimestamp: 340,
      ),
    ];
  }

  List<Note> get _filteredNotes {
    return _notes.where((note) {
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.contains(_searchQuery) ||
          note.content.contains(_searchQuery);
      final matchesTag =
          _selectedTag == null || note.tags.contains(_selectedTag);
      return matchesSearch && matchesTag;
    }).toList()
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  Set<String> get _allTags {
    final tags = <String>{};
    for (var note in _notes) {
      tags.addAll(note.tags);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              SizedBox(height: 16),

              // Search Bar
              _buildSearchBar(),

              SizedBox(height: 12),

              // Tags Filter
              if (_allTags.isNotEmpty) _buildTagsFilter(),

              SizedBox(height: 16),

              // Notes List
              Expanded(
                child: _filteredNotes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildNoteCard(_filteredNotes[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAddButton(),
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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'ملاحظاتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getMutedTextColor(context),
                width: 1,
              ),
            ),
            child: TextField(
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'ابحث في الملاحظات...',
                hintStyle: TextStyle(
                  color: AppColors.getTextColor(context, secondary: true),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.getTextColor(context, secondary: true),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildTagChip('الكل', null),
          SizedBox(width: 8),
          ..._allTags.map((tag) {
            return Padding(
              padding: EdgeInsets.only(left: 8),
              child: _buildTagChip(tag, tag),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, String? tag) {
    final isSelected = _selectedTag == tag;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedTag = tag;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
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
              color: note.isPinned
                  ? Colors.amber.withOpacity(0.5)
                  : Colors.white.withOpacity(0.3),
              width: note.isPinned ? 2 : 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteDetailScreen(note: note),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _initializeMockData();
                  });
                }
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.isPinned)
                          Icon(
                            Icons.push_pin,
                            color: Colors.amber,
                            size: 20,
                          ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Content Preview
                    Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextColor(context, secondary: true),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 12),

                    // Tags and Timestamp
                    Row(
                      children: [
                        if (note.tags.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: note.tags.take(2).map((tag) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.getMutedTextColor(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.getTextColor(context),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (note.videoTimestamp != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
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
                                SizedBox(width: 4),
                                Text(
                                  note.formattedTimestamp,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getTextColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 8),

                    // Date
                    Text(
                      _formatDate(note.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextColor(context, secondary: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📝',
            style: TextStyle(fontSize: 64),
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد ملاحظات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ابدأ بإضافة ملاحظاتك الأولى',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.getTextColor(context, secondary: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.5),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNoteScreen(),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _initializeMockData();
                  });
                }
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppColors.getTextColor(context)),
                    SizedBox(width: 8),
                    Text(
                      'ملاحظة جديدة',
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
