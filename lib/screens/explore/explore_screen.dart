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
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverPadding( // Changed to non-const to allow _t()
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _t('explore_courses'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Categories List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: _categories.isEmpty && !_isLoading
                  ? Center(child: Text(_t('no_categories_found'), style: const TextStyle(color: Colors.white)))
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _isLoading ? 5 : _categories.length,
                    itemBuilder: (context, index) {
                       if (_isLoading) {
                         return Shimmer.fromColors(
                           baseColor: Colors.white10,
                           highlightColor: Colors.white24,
                           child: Container(
                             width: 100, 
                             margin: const EdgeInsets.only(right: 12),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(16)
                             ),
                           ),
                         );
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

              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),

              // Search Bar (Optional, can be its own widget)
              // ...

              // Courses Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _isLoading 
                ? SliverToBoxAdapter(child: _buildShimmerGrid())
                : _filteredCourses.isEmpty
                  ? SliverToBoxAdapter(child: Center(child: Text(_t('no_courses_in_category'), style: const TextStyle(color: Colors.white70))))
                  : SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return CourseCard(
                            course: _filteredCourses[index],
                            heroTag: 'explore_course_image_${_filteredCourses[index].id}',
                          );
                        },
                        childCount: _filteredCourses.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // Responsive?
                        childAspectRatio: 0.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                    ),
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Space for BottomNav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
           baseColor: Colors.white10,
           highlightColor: Colors.white24,
           child: Container(
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(12)
             ),
           ),
        );
      },
    );
  }
}
