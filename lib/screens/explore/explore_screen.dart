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
import '../../core/providers/navigation_provider.dart';

class ExploreScreen extends StatefulWidget {
  final String? initialFilter;
  final bool showBackButton;
  const ExploreScreen(
      {super.key, this.initialFilter, this.showBackButton = false});

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
  String _selectedType = 'all'; // all, recorded, live, in_person
  String _selectedLevel = 'all'; // all, beginner, intermediate, advanced
  String? _initialFilter;
  final FocusNode _searchFocusNode = FocusNode();

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _initialFilter = widget.initialFilter;
    if (_initialFilter != null &&
        _initialFilter != 'newest' &&
        _initialFilter != 'popular' &&
        _initialFilter != 'recorded') {
      _selectedCategoryId = _initialFilter;
    }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navProvider = Provider.of<NavigationProvider>(context);
    if (navProvider.currentIndex == 1 && navProvider.shouldFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
          navProvider.consumeSearchFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _applyFilters() {
    List<Course> filtered = _allCourses;

    // Filter by category
    if (_selectedCategoryId != null) {
      // Find all subcategories for the selected category
      final subCatIds = _categories
          .where((c) => c.parentId == _selectedCategoryId)
          .map((c) => c.id)
          .toList();

      filtered = filtered.where((course) {
        // Check if the course belongs to this category or its subcategories via category IDs
        if (course.categoryIds.contains(_selectedCategoryId)) return true;

        // Also check if the course belongs to any subcategory of the selected one
        if (course.categoryIds.any((cid) => subCatIds.contains(cid)))
          return true;

        // Also check the category names against the selected category model (fallback)
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

    // Filter by Type
    if (_selectedType != 'all') {
      final typeMatch = _getTypeLabel(_selectedType);
      filtered = filtered.where((course) {
        return course.tags.contains(typeMatch) || course.tags.isEmpty;
      }).toList();
    }

    // Filter by Level
    if (_selectedLevel != 'all') {
      final levelMatch = _getLevelLabel(_selectedLevel);
      filtered = filtered.where((course) {
        return course.level == levelMatch || course.level == null;
      }).toList();
    }

    // Handle initialFilter (if not already handled by categorical filters above)
    if (_initialFilter != null) {
      if (_initialFilter == 'newest') {
        filtered.sort((a, b) {
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
      } else if (_initialFilter == 'popular') {
        filtered.sort((a, b) => b.studentsCount.compareTo(a.studentsCount));
      } else if (_initialFilter == 'recorded') {
        filtered =
            filtered.toList(); // Since all courses are VOD uploaded courses
      }
      // Reset after first apply to allow user navigation to change it?
      // Or keep it. Usually initial means start state.
    }

    // Ensure unique courses by ID
    final seenIds = <String>{};
    _filteredCourses = filtered.where((c) => seenIds.add(c.id)).toList();
  }

  List<CategoryModel> get _displayCategories {
    if (_selectedCategoryId != null) {
      // 1. Check if the selected category has children (subcategories)
      final subCategories =
          _categories.where((c) => c.parentId == _selectedCategoryId).toList();
      if (subCategories.isNotEmpty) {
        return subCategories;
      }

      // 2. If no children, check if it is a subcategory itself and return siblings
      final selectedCat =
          _categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
      if (selectedCat != null &&
          selectedCat.parentId != null &&
          selectedCat.parentId!.isNotEmpty) {
        return _categories
            .where((c) => c.parentId == selectedCat.parentId)
            .toList();
      }

      // 3. If it's a parent with no children, return empty (don't show bubbles)
      return [];
    }
    // Default: return nothing for bubbles if no parent category selected in dropdown
    return [];
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      if (_selectedCategoryId == categoryId) {
        // Deselecting: if it's a subcategory, maybe go back to parent? Or just null
        final selectedCat =
            _categories.where((c) => c.id == categoryId).firstOrNull;
        if (selectedCat != null &&
            selectedCat.parentId != null &&
            selectedCat.parentId!.isNotEmpty) {
          _selectedCategoryId = selectedCat.parentId; // Go up a level
        } else {
          _selectedCategoryId = null; // Go to root
        }
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryTextColor = AppColors.getTextColor(context);
    final Color secondaryTextColor =
        AppColors.getTextColor(context, secondary: true);
    final Color surfaceColor = isDark
        ? AppColors.darkCardSurface.withOpacity(0.88)
        : Colors.white.withOpacity(0.78);
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : AppColors.primaryPurple.withOpacity(0.18);
    final Color subtleSurfaceColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.38);
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

    final displayCats = _displayCategories;

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _loadData(forceRefresh: true),
            color: AppColors.primaryPurple,
            backgroundColor: surfaceColor,
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
                          if (widget.showBackButton)
                            Container(
                              margin: const EdgeInsets.only(left: 8, right: 8),
                              decoration: BoxDecoration(
                                color: subtleSurfaceColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Provider.of<LocaleProvider>(context,
                                                  listen: false)
                                              .locale ==
                                          'ar'
                                      ? Icons.arrow_forward_ios_rounded
                                      : Icons.arrow_back_ios_new_rounded,
                                  color: primaryTextColor,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          Text(
                            _t('explore_courses'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.normal,
                              color: primaryTextColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: subtleSurfaceColor,
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
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: borderColor,
                              ),
                            ),
                            child: TextField(
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                  color: AppColors.getTextColor(context)),
                              cursorColor: AppColors.primaryPurple,
                              decoration: InputDecoration(
                                hintText: _t('search_course_hint'),
                                hintStyle: TextStyle(
                                  color: AppColors.getTextColor(context,
                                      secondary: true),
                                ),
                                prefixIcon: Icon(Icons.search,
                                    color: AppColors.getTextColor(context,
                                        secondary: true)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  _t('type_label'),
                                  _selectedType,
                                  ['all', 'recorded', 'live', 'in_person'],
                                  (val) {
                                    setState(() {
                                      _selectedType = val!;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDropdown(
                                  _t('level_label'),
                                  _selectedLevel,
                                  [
                                    'all',
                                    'beginner',
                                    'intermediate',
                                    'advanced'
                                  ],
                                  (val) {
                                    setState(() {
                                      _selectedLevel = val!;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCategoryDropdown(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 16)),

                  if (displayCats.isNotEmpty &&
                      _selectedCategoryId != null) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: Text(
                                _categories.any((c) =>
                                        c.id == _selectedCategoryId &&
                                        (c.parentId == null ||
                                            c.parentId!.isEmpty))
                                    ? 'التصنيفات الفرعية'
                                    : 'تصنيفات مشابهة',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemCount: _isLoading ? 5 : displayCats.length,
                                itemBuilder: (context, index) {
                                  if (_isLoading) {
                                    return _buildShimmerCategory();
                                  }
                                  final cat = displayCats[index];
                                  return CategoryCard(
                                    category: cat,
                                    isSelected: _selectedCategoryId == cat.id,
                                    onTap: () => _onCategorySelected(cat.id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

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
                                      color:
                                          secondaryTextColor.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(_t('no_courses_in_category'),
                                      style:
                                          TextStyle(color: secondaryTextColor)),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedCategoryId = null;
                                        _searchQuery = '';
                                        _applyFilters();
                                      });
                                    },
                                    icon: Icon(
                                      Icons.refresh,
                                      color: secondaryTextColor,
                                    ),
                                    label: Text(_t('show_all'),
                                        style: TextStyle(
                                            color: secondaryTextColor)),
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

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)), // Space for BottomNav
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final parentCategories = _categories
        .where((c) => c.parentId == null || c.parentId!.isEmpty)
        .toList();
    final locale = Provider.of<LocaleProvider>(context).locale;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardSurface.withOpacity(0.88)
            : Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.14)
              : AppColors.primaryPurple.withOpacity(0.16),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: (_selectedCategoryId != null &&
                  (_categories
                      .where((c) =>
                          c.id == _selectedCategoryId &&
                          (c.parentId == null || c.parentId!.isEmpty))
                      .isNotEmpty))
              ? _selectedCategoryId
              : (_selectedCategoryId != null
                  ? _categories
                      .where((c) => c.id == _selectedCategoryId)
                      .firstOrNull
                      ?.parentId
                  : null),
          isExpanded: true,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardSurface
              : Colors.white,
          icon: Icon(Icons.arrow_drop_down,
              color: AppColors.getTextColor(context, secondary: true)),
          style:
              TextStyle(color: AppColors.getTextColor(context), fontSize: 13),
          onChanged: (val) {
            setState(() {
              _selectedCategoryId = val;
              _applyFilters();
            });
          },
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                _t('all_categories'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ),
            ...parentCategories.map((cat) {
              return DropdownMenuItem<String?>(
                value: cat.id,
                child: Text(
                  cat.getLocalizedName(locale),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
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
                color: Colors.white, borderRadius: BorderRadius.circular(24)),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardSurface.withOpacity(0.88)
            : Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.14)
              : AppColors.primaryPurple.withOpacity(0.16),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardSurface
              : Colors.white,
          icon: Icon(Icons.arrow_drop_down,
              color: AppColors.getTextColor(context, secondary: true)),
          style:
              TextStyle(color: AppColors.getTextColor(context), fontSize: 13),
          onChanged: onChanged,
          selectedItemBuilder: (context) {
            return options.map((opt) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _getLocalizedOption(opt),
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 12,
                  ),
                ),
              );
            }).toList();
          },
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                _getLocalizedOption(opt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextColor(context),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getLocalizedOption(String opt) {
    switch (opt) {
      case 'all':
        return _t('all');
      case 'recorded':
        return _t('recorded');
      case 'live':
        return _t('live');
      case 'in_person':
        return _t('in_person');
      case 'beginner':
        return _t('beginner');
      case 'intermediate':
        return _t('intermediate');
      case 'advanced':
        return _t('advanced');
      default:
        return opt;
    }
  }

  String _getTypeLabel(String key) {
    switch (key) {
      case 'recorded':
        return 'محملة';
      case 'live':
        return 'بث مباشر';
      case 'in_person':
        return 'حضورية';
      default:
        return 'الكل';
    }
  }

  String _getLevelLabel(String key) {
    switch (key) {
      case 'beginner':
        return 'مبتدئ';
      case 'intermediate':
        return 'متوسط';
      case 'advanced':
        return 'متقدم';
      default:
        return 'الكل';
    }
  }
}
