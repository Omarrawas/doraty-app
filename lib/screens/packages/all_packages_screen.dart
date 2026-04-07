import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../widgets/bundle_card.dart';
import '../../models/bundle.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/database_service.dart';

class AllPackagesScreen extends StatefulWidget {
  const AllPackagesScreen({super.key});

  @override
  State<AllPackagesScreen> createState() => _AllPackagesScreenState();
}

class _AllPackagesScreenState extends State<AllPackagesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Bundle> _allBundles = [];
  List<Bundle> _filteredBundles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _currentSort = 'newest'; // newest, price_low, price_high

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  Future<void> _loadBundles() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _databaseService.getBundles();
      if (mounted) {
        setState(() {
          _allBundles = data.map((e) => Bundle.fromJson(e)).toList();
          _filterAndSortBundles();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading bundles: $e');
      }
    }
  }

  void _filterAndSortBundles() {
    List<Bundle> results = List.from(_allBundles);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      results = results.where((b) {
        final titleMatch = b.title.toLowerCase().contains(lowerQuery);
        final descMatch =
            (b.description ?? '').toLowerCase().contains(lowerQuery);
        return titleMatch || descMatch;
      }).toList();
    }

    // Apply sorting
    if (_currentSort == 'price_low') {
      results.sort((a, b) => a.price.compareTo(b.price));
    } else if (_currentSort == 'price_high') {
      results.sort((a, b) => b.price.compareTo(a.price));
    } else {
      // Newest (Default, usually from DB order or ID)
      // Assuming original order is newest to oldest based on creation
    }

    setState(() {
      _filteredBundles = results;
    });
  }

  void _showFilterBottomSheet(BuildContext context, String Function(String) t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context).withOpacity(0.8),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    t('filter_sort'), // e.g., Filter & Sort
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSortOption(t('newest'), 'newest'),
                  _buildSortOption(t('lowest_price'), 'price_low'),
                  _buildSortOption(t('highest_price'), 'price_high'),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        t('apply'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _currentSort == value;
    return InkWell(
      onTap: () {
        setState(() => _currentSort = value);
        _filterAndSortBundles();
        Navigator.pop(
            context); // Close safely to repopulate state if using stateful builder
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppColors.primaryPurple : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primaryPurple
                    : AppColors.getTextColor(context),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Safely get string, fallback if missing
    String t(String key) {
      final str = AppStrings.get(key, locale);
      if (str == key && key == 'filter_sort') {
        return locale == 'ar' ? 'الفرز والتصفية' : 'Sort & Filter';
      }
      if (str == key && key == 'lowest_price') {
        return locale == 'ar' ? 'السعر: الأقل إلى الأعلى' : 'Price: Low to High';
      }
      if (str == key && key == 'highest_price') {
        return locale == 'ar' ? 'السعر: الأعلى إلى الأقل' : 'Price: High to Low';
      }
      if (str == key && key == 'apply') {
        return locale == 'ar' ? 'تطبيق' : 'Apply';
      }
      if (str == key && key == 'newest') {
        return locale == 'ar' ? 'الأحدث' : 'Newest';
      }
      return str;
    }

    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth > 1400) {
      crossAxisCount = 5;
      childAspectRatio = 1.35;
    } else if (screenWidth > 1100) {
      crossAxisCount = 4;
      childAspectRatio = 1.3;
    } else if (screenWidth > 850) {
      crossAxisCount = 3;
      childAspectRatio = 1.25;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.45;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 2.4;
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(t('all_bundles'), style: const TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.getGlassColor(context,
                                  opacity: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: TextField(
                              style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontFamily: 'Cairo'),
                              onChanged: (val) {
                                _searchQuery = val;
                                _filterAndSortBundles();
                              },
                              decoration: InputDecoration(
                                hintText: '${t('searching')}...',
                                hintStyle: TextStyle(
                                    color: AppColors.getTextColor(context)
                                        .withOpacity(0.54),
                                    fontSize: 14,
                                    fontFamily: 'Cairo'),
                                border: InputBorder.none,
                                icon: Icon(Icons.search,
                                    color: AppColors.getTextColor(context)
                                        .withOpacity(0.54)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _showFilterBottomSheet(context, t),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Icon(Icons.filter_list,
                                color: Colors
                                    .white), // Standardized to white to ensure contrast
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBundles.isEmpty
                        ? Center(
                            child: Text(t('no_courses_found'),
                                style: TextStyle(
                                    color: AppColors.getTextColor(context)
                                        .withOpacity(0.54),
                                    fontFamily: 'Cairo')))
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 24,
                                ),
                                itemCount: _filteredBundles.length,
                                itemBuilder: (context, index) {
                                  return BundleCard(
                                    bundle: _filteredBundles[index],
                                    heroTag:
                                        'all_bundles_list_${_filteredBundles[index].id}',
                                  );
                                },
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
}
