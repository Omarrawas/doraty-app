import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import '../../models/category_model.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import 'category_courses_screen.dart';
import 'package:doraty/core/constants/app_strings.dart';

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
              .where((cat) => cat.parentId == null || cat.parentId!.isEmpty)
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
    return '📚';
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
                          Consumer<LocaleProvider>(
                            builder: (context, localeProvider, _) => Text(
                              AppStrings.get('categories_title', localeProvider.locale),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                  icon: Icon(
                    Provider.of<LocaleProvider>(context, listen: false).locale == 'ar'
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ) : const SizedBox(width: 48, height: 48),
              ),
            ),
          ),
          Expanded(
            child: Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) => Text(
                AppStrings.get('categories_title', localeProvider.locale),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_categories.isEmpty && !_isLoading) {
      // Show fallback if no real categories found
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: _fallbackCategories.length,
        itemBuilder: (context, index) => _buildFallbackCard(_fallbackCategories[index], index),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBox(category: category, color: color),
          const SizedBox(height: 16),
          Text(
            category.getLocalizedName(locale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600, 
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              category.icon,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            category.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600, 
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C), // Dark surface like in image 2
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final CategoryModel category;
  final Color color;
  const _IconBox({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: _buildIcon(context),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // If iconUrl is a material icon name, use it
    if (category.iconUrl != null && !category.iconUrl!.startsWith('http')) {
      return Icon(_getMaterialIcon(category.iconUrl!), color: color, size: 32);
    }
    
    // Otherwise fallback to name-based mapping or generic
    final mapping = {
      'التعليم التربوي': Icons.menu_book,
      'التصميم الداخلي': Icons.apartment,
      'العلوم والتكنولوجيا': Icons.science,
      'إدارة الأعمال': Icons.business_center,
      'نمط الحياة': Icons.directions_run,
      'الإبداع': Icons.palette,
      'لغات': Icons.language,
      'تعليم مدرسي': Icons.school,
    };

    IconData icon = mapping[category.name] ?? Icons.category_outlined;
    return Icon(icon, color: color, size: 32);
  }

  IconData _getMaterialIcon(String name) {
    switch (name.toLowerCase()) {
      case 'book': return Icons.menu_book;
      case 'home': return Icons.home;
      case 'science': return Icons.science;
      case 'business': return Icons.business;
      case 'money': return Icons.attach_money;
      case 'palette': return Icons.palette;
      case 'fitness': return Icons.fitness_center;
      case 'school': return Icons.school;
      default: return Icons.category;
    }
  }
}
