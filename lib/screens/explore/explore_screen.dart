import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
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
  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  bool _isLoading = true;
  String? _selectedCategoryId;
  String _searchQuery = '';

  String _t(String key) =>
      AppStrings.get(key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      // Load Categories and Courses in parallel
      final results = await Future.wait([
        _databaseService.getCategories(forceRefresh: forceRefresh),
        _databaseService.getCourses(
            includeDrafts: false, forceRefresh: forceRefresh),
      ]);

      final categoriesData = results[0];
      final coursesData = results[1];

      final categories =
          categoriesData.map((e) => CategoryModel.fromJson(e)).toList();
      final courses = coursesData.map((c) => Course.fromJson(c)).toList();

      // If cache returned empty courses and this was not a forced refresh,
      // retry with forceRefresh to get fresh data from the server
      if (courses.isEmpty && !forceRefresh) {
        debugPrint('⚠️ Cache returned empty courses, forcing refresh...');
        await _loadData(forceRefresh: true);
        return;
      }

      if (mounted) {
        setState(() {
          _categories = categories;
          _allCourses = courses;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading explore data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Course> filtered = _allCourses;

    // Filter by category
    if (_selectedCategoryId != null) {
      filtered = filtered.where((course) {
        // Check if the course belongs to this category via category IDs
        if (course.categoryIds.contains(_selectedCategoryId)) return true;

        // Also check the category names against the selected category model
        final selectedCat =
            _categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
        if (selectedCat != null) {
          final catName = selectedCat.name.toLowerCase();
          final catNameEn = selectedCat.nameEn?.toLowerCase() ?? '';
          return course.categories.any((c) =>
                  c.toLowerCase() == catName || c.toLowerCase() == catNameEn) ||
              course.subject.toLowerCase() == catName ||
              course.subject.toLowerCase() == catNameEn;
        }
        return false;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((course) {
        return course.title.toLowerCase().contains(query) ||
            (course.description ?? '').toLowerCase().contains(query) ||
            course.subject.toLowerCase().contains(query) ||
            course.instructorName.toLowerCase().contains(query);
      }).toList();
    }

    // Ensure unique courses by ID
    final seenIds = <String>{};
    _filteredCourses = filtered.where((c) => seenIds.add(c.id)).toList();
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      if (_selectedCategoryId == categoryId) {
        // Deselect
        _selectedCategoryId = null;
      } else {
        _selectedCategoryId = categoryId;
      }
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2; // Default to 2 columns for better mobile experience
    double childAspectRatio = 0.65; // Balanced for 2 columns

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.72;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.68;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.62;
    }

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _loadData(forceRefresh: true),
            color: Colors.white,
            backgroundColor: Colors.deepPurple,
            child: Scrollbar(
              thickness: 6,
              radius: const Radius.circular(10),
              interactive: true,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
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

                  // Search Bar
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.getGlassColor(context, opacity: 0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.getGlassColor(context, opacity: 0.2),
                          ),
                        ),
                        child: TextField(
                          style: TextStyle(color: AppColors.getTextColor(context)),
                          cursorColor: AppColors.primaryPurple,
                          decoration: InputDecoration(
                            hintText: _t('search_course_hint'),
                            hintStyle: TextStyle(
                              color: AppColors.getTextColor(context, secondary: true),
                            ),
                            prefixIcon: Icon(Icons.search,
                                color: AppColors.getTextColor(context, secondary: true)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 16)),

                  // Categories List (Circular)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: _categories.isEmpty && !_isLoading
                          ? Center(
                              child: Text(_t('no_categories_found'),
                                  style: const TextStyle(color: Colors.white)))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedCategoryId = null;
                                        _searchQuery = '';
                                        _applyFilters();
                                      });
                                    },
                                    icon: const Icon(Icons.refresh,
                                        color: Colors.white70),
                                    label: Text(_t('show_all'),
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  ),
                                ],
                              )))
                            : SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return CourseCard(
                                      course: _filteredCourses[index],
                                      heroTag:
                                          'explore_course_image_${_filteredCourses[index].id}',
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
