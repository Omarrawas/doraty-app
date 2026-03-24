import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category_model.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';

class CategoryCoursesScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryCoursesScreen({super.key, required this.category});

  @override
  State<CategoryCoursesScreen> createState() => _CategoryCoursesScreenState();
}

class _CategoryCoursesScreenState extends State<CategoryCoursesScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<CategoryModel> _subCategories = [];
  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  String? _selectedSubCategoryId;
  bool _isLoading = true;
  String _locale = 'ar';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _locale = Provider.of<LocaleProvider>(context, listen: false).locale;

    try {
      // 1. Load subcategories
      final subCatsData = await _dbService.getSubCategories(widget.category.id);
      _subCategories = subCatsData.map((json) => CategoryModel.fromJson(json)).toList();

      // 2. Load courses for the main category
      final coursesData = await _dbService.getCourses(categoryId: widget.category.id);
      _allCourses = coursesData.map((json) => Course.fromJson(json)).toList();
      _filteredCourses = _allCourses;
      
    } catch (e) {
      debugPrint('Error loading category courses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSubCategorySelected(String? subCategoryId) {
    setState(() {
      _selectedSubCategoryId = subCategoryId;
      if (subCategoryId == null) {
        _filteredCourses = _allCourses;
      } else {
        // In a real app, we might want to fetch from DB if not already loaded
        // For now, let's filter what we have or fetch if the junction logic is correct
        _fetchCoursesForSubCategory(subCategoryId);
      }
    });
  }

  Future<void> _fetchCoursesForSubCategory(String subCategoryId) async {
    setState(() => _isLoading = true);
    try {
      final coursesData = await _dbService.getCourses(categoryId: subCategoryId);
      if (mounted) {
        setState(() {
          _filteredCourses = coursesData.map((json) => Course.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching subcategory courses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 1200 ? 4 : (size.width > 800 ? 3 : 2);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.primaryPurple,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.category.getLocalizedName(_locale),
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark ? AppColors.darkBackgroundGradient : AppColors.backgroundGradient,
                ),
                child: Opacity(
                  opacity: 0.1,
                  child: Center(
                    child: Icon(
                      Icons.category_outlined,
                      size: 150,
                      color: AppColors.getMutedTextColor(context),
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: IconThemeData(color: AppColors.getTextColor(context)),
          ),

          // Sub-category Filter Bar
          if (_subCategories.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 60,
                padding: EdgeInsets.symmetric(vertical: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _subCategories.length + 1,
                  itemBuilder: (context, index) {
                    final bool isAll = index == 0;
                    final subCat = isAll ? null : _subCategories[index - 1];
                    final String label = isAll 
                        ? AppStrings.get('all', _locale) 
                        : subCat!.getLocalizedName(_locale);
                    final String? id = isAll ? null : subCat!.id;
                    final bool isSelected = _selectedSubCategoryId == id;

                    return Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => _onSubCategorySelected(id),
                        selectedColor: AppColors.primaryPurple,
                        backgroundColor: isDark ? Colors.white10 : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryPurple : (isDark ? Colors.white24 : Colors.grey.shade200),
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Courses Grid
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: _isLoading
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildShimmerCard(),
                      childCount: 6,
                    ),
                  )
                : _filteredCourses.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                              SizedBox(height: 16),
                              Text(
                                AppStrings.get('no_courses_found', _locale),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => CourseCard(course: _filteredCourses[index]),
                          childCount: _filteredCourses.length,
                        ),
                      ),
          ),
          
          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getTextColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
