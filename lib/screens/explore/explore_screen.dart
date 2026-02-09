import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/category_model.dart';
import '../../models/course.dart';
import '../../widgets/course_card.dart';
import 'widgets/category_card.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  List<CategoryModel> _categories = [];
  // List<Course> _allCourses = []; // Unused
  List<Course> _filteredCourses = [];
  bool _isLoading = true;
  String? _selectedCategoryId;

  String _t(String key) =>
      AppStrings.get(key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load Categories
      final categoriesData = await _databaseService.getCategories();
      final categories = categoriesData.map((e) => CategoryModel.fromJson(e)).toList();

      // Load All Courses (or featured/popular)
      // Ideally we should paginate, but for now fetch all published
      final coursesData = await _databaseService.getCourses(includeDrafts: false);
      final courses = coursesData.map((c) => Course.fromJson(c)).toList();

      if (mounted) {
        setState(() {
          _categories = categories;
          final seenIds = <String>{};
          _filteredCourses = courses.where((c) => seenIds.add(c.id)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading explore data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onCategorySelected(String? categoryId) async {
    if (_selectedCategoryId == categoryId) {
      // Deselect
      setState(() {
        _selectedCategoryId = null;
      });
      await _loadCourses();
    } else {
      setState(() {
        _selectedCategoryId = categoryId;
      });
      await _loadCourses(categoryId: categoryId);
    }
  }

  Future<void> _loadCourses({String? categoryId}) async {
    setState(() => _filteredCourses = []); // Show loading list or keep old?
    // Let's keep old and show loading indicator maybe? or just wait.
    
    try {
      final coursesData = await _databaseService.getCourses(
        categoryId: categoryId,
        includeDrafts: false,
      );
      
      final courses = coursesData.map((c) => Course.fromJson(c)).toList();
      
      if (mounted) {
        setState(() {
          final seenIds = <String>{};
          _filteredCourses = courses.where((c) => seenIds.add(c.id)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error filtering courses: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 0.65;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.75;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.7;
    }

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Scrollbar(
            thickness: 6,
            radius: const Radius.circular(10),
            interactive: true,
            child: CustomScrollView(
              slivers: [
                // Header
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('explore_courses'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                        // Small Decoration like Home
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.amber, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),

                // Categories List (Now Circular)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: _categories.isEmpty && !_isLoading
                        ? Center(
                            child: Text(_t('no_categories_found'),
                                style: const TextStyle(color: Colors.white)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _isLoading ? 5 : _categories.length,
                            itemBuilder: (context, index) {
                              if (_isLoading) {
                                return _buildShimmerCategory();
                              }

                              final cat = _categories[index];
                              return CategoryCard(
                                category: cat,
                                isSelected: _selectedCategoryId == cat.id,
                                onTap: () => _onCategorySelected(cat.id),
                              );
                            },
                          ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),

                // Courses Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _isLoading 
                      ? SliverToBoxAdapter(
                          child: _buildShimmerGrid(
                              crossAxisCount, childAspectRatio))
                      : _filteredCourses.isEmpty
                          ? SliverToBoxAdapter(
                              child: Center(
                                  child: Column(
                              children: [
                                const SizedBox(height: 60),
                                Icon(Icons.search_off,
                                    size: 64,
                                    color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(_t('no_courses_in_category'),
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ],
                            )))
                          : SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return CourseCard(
                                    course: _filteredCourses[index],
                                    heroTag:
                                        'explore_course_image_${_filteredCourses[index].id}',
                                    showEnrollButton:
                                        true, // Matches Home Style
                                  );
                                },
                                childCount: _filteredCourses.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                            ),
                ),
                
                const SliverPadding(
                    padding:
                        EdgeInsets.only(bottom: 100)), // Space for BottomNav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCategory() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 75,
              height: 75,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 10,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(int crossAxisCount, double aspectRatio) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
           baseColor: Colors.white10,
           highlightColor: Colors.white24,
           child: Container(
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(24)
             ),
           ),
        );
      },
    );
  }
}
