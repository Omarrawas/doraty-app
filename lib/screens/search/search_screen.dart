import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async'; // Added for Timer
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/course.dart';
import '../../models/category_model.dart';
import '../../widgets/course_card.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  CategoryModel? _selectedCategory;
  double _minPrice = 0;
  double _maxPrice = 100000;
  double _minRating = 0;
  bool _showFilters = false;

  List<CategoryModel> _categories = [];
  List<Course> _searchResults = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _databaseService.getCategories();
      if (mounted) {
        setState(() {
          _categories = data.map((json) => CategoryModel.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories in SearchScreen: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch();
      }
    });
  }


  bool _isLoading = false;

  void _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final query = _searchController.text.trim();
      final results = await _databaseService.searchCourses(
        query: query,
        categoryId: _selectedCategory?.id,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 1000000 ? _maxPrice : null,
        minRating: _minRating > 0 ? _minRating : null,
      );

      if (mounted) {
        setState(() {
          _searchResults =
              results.map((data) => Course.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
          );
        });
      }
    }
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
              // Header
              _buildHeader(),

              const SizedBox(height: 20),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSearchBar(),
              ),

              const SizedBox(height: 16),

              // Filter Toggle Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildFilterToggle(),
              ),

              // Filters Panel
              if (_showFilters) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildFiltersPanel(),
                ),
              ],

              const SizedBox(height: 20),

              // Search Results
              Expanded(
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: 5,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: CourseCardShimmer(),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child:
                                    CourseCard(course: _searchResults[index]),
                              );
                            },
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
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'البحث عن الدورات',
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

  Widget _buildSearchBar() {
    return Hero(
      tag: 'search_bar_home',
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
            ),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث عن الدورات والمواد',
                hintStyle: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.black54,
                  ),
                  onPressed: _performSearch,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildFilterToggle() {
    return ClipRRect(
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showFilters
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'الفلاتر المتقدمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.filter_list,
                      color: Colors.white,
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

  Widget _buildFiltersPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
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
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Subject Filter
              const Text(
                'المادة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    label: 'الكل',
                    isSelected: _selectedCategory == null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                  ),
                  ..._categories.map((category) {
                    final isSelected = category.id == _selectedCategory?.id;
                    return _buildFilterChip(
                      label: category.name,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  }),
                ],
              ),

              const SizedBox(height: 20),

              // Price Range
              const Text(
                'نطاق السعر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 1000000,
                divisions: 20,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withOpacity(0.3),
                labels: RangeLabels(
                  '${_minPrice.toInt()}',
                  '${_maxPrice.toInt()}',
                ),
                onChanged: (values) {
                  setState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Rating Filter
              const Text(
                'التقييم الأدنى',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _minRating = rating.toDouble();
                        });
                      },
                      child: Icon(
                        rating <= _minRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _performSearch,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'تطبيق الفلاتر',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF7B2CBF),
                      Color(0xFF5A67D8),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _buildEmptyState() {
    if (_searchController.text.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'تصفح حسب التصنيف',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _categories.isEmpty 
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Colors.white70),
                  ))
                : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.3,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _buildCategoryItem(category);
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    return ProfessionalEmptyState(
      title: 'لا توجد نتائج',
      message: 'لم نتمكن من العثور على أي دورات تطابق بحثك. حاول تغيير كلمات البحث أو الفلاتر.',
      icon: Icons.search_off_rounded,
    );
  }

  Widget _buildCategoryItem(CategoryModel category) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _showFilters = true; // Show filters to indicate selection
        });
        _performSearch();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: AppColors.primaryPurple.withOpacity(0.2),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.category, color: Colors.white, size: 24), // Placeholder if iconUrl is not image
              )
            else
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: AppColors.primaryPurple.withOpacity(0.2),
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.category, color: Colors.white, size: 24),
              ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
