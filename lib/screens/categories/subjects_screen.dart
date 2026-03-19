import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import '../../models/category_model.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import 'category_courses_screen.dart';

class SubjectsScreen extends StatefulWidget {
  final bool showBackButton;
  const SubjectsScreen({super.key, this.showBackButton = true});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  late List<Category> _fallbackCategories;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeFallbackCategories();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dbService.getCategories();
      if (mounted) {
        setState(() {
          _categories = data
              .map((json) => CategoryModel.fromJson(json))
              .where((cat) => cat.parentId == null)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeFallbackCategories() {
    final scientificSubjects = [
      'الرياضيات', 'الفيزياء', 'الكيمياء', 'الأحياء', 'اللغة العربية', 'اللغة الإنجليزية', 'اللغة الفرنسية', 'الديانة',
    ];
    final literarySubjects = [
      'التاريخ', 'الجغرافيا', 'الفلسفة', 'علم الاجتماع',
    ];

    final allSubjects = {...scientificSubjects, ...literarySubjects}.toList();

    _fallbackCategories = allSubjects.asMap().entries.map((entry) {
      return Category(
        id: '${entry.key + 1}',
        name: entry.value,
        description: 'دورات ${entry.value} للثانوية العامة',
        icon: _getIconForSubject(entry.value),
        coursesCount: (entry.key + 1) * 3,
      );
    }).toList();
  }

  String _getIconForSubject(String subject) {
    final icons = {
      'الرياضيات': '📐', 'الفيزياء': '⚛️', 'الكيمياء': '🧪', 'الأحياء': '🧬',
      'التاريخ': '📜', 'الجغرافيا': '🌍', 'الفلسفة': '🤔', 'علم الاجتماع': '👥',
      'اللغة العربية': '📖', 'اللغة الإنجليزية': '🇬🇧', 'اللغة الفرنسية': '🇫🇷',
      'الديانة': '☪️',
    };
    return icons[subject] ?? '📚';
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFF7B2CBF), const Color(0xFF5A67D8), const Color(0xFFE91E63),
      const Color(0xFFFF6B9D), const Color(0xFF00BCD4), const Color(0xFF4CAF50),
      const Color(0xFFFF9800), const Color(0xFF9C27B0),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'المواد الدراسية',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGrid(),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: widget.showBackButton ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ) : const SizedBox(width: 48, height: 48),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'المواد الدراسية',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 1200 ? 5 : (size.width > 800 ? 4 : (size.width > 550 ? 2 : 1));
    
    if (_categories.isEmpty && !_isLoading) {
      // Show fallback if no real categories found
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: size.width < 550 ? 2.2 : 0.85,
        ),
        itemCount: _fallbackCategories.length,
        itemBuilder: (context, index) => _buildFallbackCard(_fallbackCategories[index], index),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: size.width < 550 ? 2.2 : 0.85,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) => _buildCategoryCard(_categories[index], index),
    );
  }

  Widget _buildCategoryCard(CategoryModel category, int index) {
    final color = _getColorForIndex(index);
    final locale = Provider.of<LocaleProvider>(context).locale;

    return _CardWrapper(
      color: color,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CategoryCoursesScreen(category: category)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: _getIconForSubject(category.name)),
          const Spacer(),
          Text(
            category.getLocalizedName(locale),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('تصفح المواد', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.8), size: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCard(Category category, int index) {
    final color = _getColorForIndex(index);

    return _CardWrapper(
      color: color,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: category.icon),
          const Spacer(),
          Text(
            category.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 16),
              const SizedBox(width: 4),
              Text('${category.coursesCount} دورة', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  const _CardWrapper({required this.color, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
    );
  }
}
