import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  List<Course> _filteredCourses = [];
  bool _isLoading = true;
  String? _selectedCategoryId;
  String _searchQuery = '';
  String _selectedType = 'all'; // all, recorded, live, in_person
  String _selectedLevel = 'all'; // all, beginner, intermediate, advanced,expert
  String? _initialFilter;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Pagination State
  int _offset = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isMoreLoading = false;

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
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (!forceRefresh) _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _filteredCourses = [];
      });
    }

    try {
      // Load Categories (Only once or on force refresh)
      if (_categories.isEmpty || forceRefresh) {
        final categoriesData = await _databaseService.getCategories(forceRefresh: forceRefresh);
        if (mounted) {
          setState(() {
            _categories = categoriesData.map((e) => CategoryModel.fromJson(e)).toList();
          });
        }
      }

      // Load Courses with server-side filters
      final coursesData = await _databaseService.getCourses(
        categoryId: _selectedCategoryId,
        level: _selectedLevel == 'all' ? null : _selectedLevel,
        query: _searchQuery,
        limit: _limit,
        offset: _offset,
        includeDrafts: false,
        deliveryMode: _selectedType == 'all' ? null : _selectedType,
        forceRefresh: forceRefresh,
      );

      final courses = coursesData.map((c) => Course.fromJson(c)).toList();

      if (mounted) {
        setState(() {
          _filteredCourses = courses;
          _hasMore = courses.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading explore data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isMoreLoading || !_hasMore) return;

    if (mounted) setState(() => _isMoreLoading = true);

    try {
      _offset += _limit;
      final coursesData = await _databaseService.getCourses(
        categoryId: _selectedCategoryId,
        level: _selectedLevel == 'all' ? null : _selectedLevel,
        query: _searchQuery,
        limit: _limit,
        offset: _offset,
        includeDrafts: false,
        deliveryMode: _selectedType == 'all' ? null : _selectedType,
      );

      final newCourses = coursesData.map((c) => Course.fromJson(c)).toList();

      if (mounted) {
        setState(() {
          // Avoid duplicates
          final existingIds = _filteredCourses.map((c) => c.id).toSet();
          final uniqueNewCourses = newCourses.where((c) => !existingIds.contains(c.id)).toList();
          
          _filteredCourses.addAll(uniqueNewCourses);
          _hasMore = newCourses.length >= _limit;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more courses: $e');
      if (mounted) setState(() => _isMoreLoading = false);
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
  void didUpdateWidget(ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _initialFilter = widget.initialFilter;
        if (_initialFilter != null &&
            _initialFilter != 'newest' &&
            _initialFilter != 'popular' &&
            _initialFilter != 'recorded') {
          _selectedCategoryId = _initialFilter;
        } else if (_initialFilter == null) {
          _selectedCategoryId = null;
        }
        _applyFilters();
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    _loadData();
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

  String? _getSelectedParentId() {
    if (_selectedCategoryId == null || _categories.isEmpty) return null;
    
    // 1. Check if the current ID is actually a parent
    final isParent = _categories.any((c) => 
        c.id == _selectedCategoryId && 
        (c.parentId == null || c.parentId!.isEmpty));
    
    if (isParent) return _selectedCategoryId;
    
    // 2. If it's a sub-category, find its parent
    final currentCat = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId, 
      orElse: () => CategoryModel(id: '', name: '', slug: '')
    );
    
    if (currentCat.id.isNotEmpty && currentCat.parentId != null && currentCat.parentId!.isNotEmpty) {
      return currentCat.parentId;
    }
    
    return null;
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
        : Colors.white.withOpacity(0.18);
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.4);
    final Color subtleSurfaceColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.20);
    int crossAxisCount = 1; // Default to 1 column for small screens (Horizontal layout)
    double childAspectRatio = 2.6; // Matches horizontal card aspect ratio
    bool isSmallScreen = screenWidth <= 550;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.72;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.68;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
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
              controller: _scrollController,
              thickness: 6,
              radius: const Radius.circular(10),
              interactive: true,
              child: CustomScrollView(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.showBackButton)
                            Container(
                              margin: EdgeInsets.only(left: 8, right: 8),
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
                                onPressed: () => context.go('/topics'),
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
                          Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Provider.of<LocaleProvider>(context, listen: false).locale == 'ar'
                                    ? Icons.arrow_back_ios_new_rounded // Use backward for left button in RTL
                                    : Icons.arrow_forward_ios_rounded,
                                color: primaryTextColor,
                                size: 20,
                              ),
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  context.go('/');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
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
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          SizedBox(height: 12),
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
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildDropdown(
                                  _t('level_label'),
                                  _selectedLevel,
                                  [
                                    'all',
                                    'beginner',
                                    'intermediate',
                                    'advanced',
                                    'expert'
                                  ],
                                  (val) {
                                    setState(() {
                                      _selectedLevel = val!;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildCategoryDropdown(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(padding: EdgeInsets.only(bottom: 16)),

                  if (displayCats.isNotEmpty &&
                      _selectedCategoryId != null) ...[
                    SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
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
                                    EdgeInsets.symmetric(horizontal: 20),
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

                  SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Courses Grid
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    sliver: _isLoading
                        ? SliverToBoxAdapter(
                            child: _buildShimmerGrid(
                                crossAxisCount, childAspectRatio))
                        : _filteredCourses.isEmpty
                            ? SliverToBoxAdapter(
                                child: Center(
                                    child: Column(
                                children: [
                                  SizedBox(height: 60),
                                  Icon(Icons.search_off,
                                      size: 64,
                                      color:
                                          secondaryTextColor.withOpacity(0.5)),
                                  SizedBox(height: 16),
                                  Text(_t('no_courses_in_category'),
                                      style:
                                          TextStyle(color: secondaryTextColor)),
                                  SizedBox(height: 16),
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
                                      isHorizontal: isSmallScreen,
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

                  if (_hasMore || _isMoreLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: _isMoreLoading
                              ? CircularProgressIndicator(
                                  color: AppColors.primaryPurple,
                                  strokeWidth: 2,
                                )
                              : SizedBox.shrink(),
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final parentCategories = _categories
        .where((c) => c.parentId == null || c.parentId!.isEmpty)
        .toList();
    final locale = Provider.of<LocaleProvider>(context).locale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardSurface.withOpacity(0.88)
            : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _getSelectedParentId(),
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
            }),
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
        margin: EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                color: AppColors.getTextColor(context),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 50,
              height: 10,
              color: AppColors.getTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(int crossAxisCount, double aspectRatio) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardSurface.withOpacity(0.88)
            : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.4),
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
      case 'expert':
        return _t('expert');
      default:
        return opt;
    }
  }
}
