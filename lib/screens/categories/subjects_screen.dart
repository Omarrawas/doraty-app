import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category_model.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:doraty/core/constants/app_strings.dart';
import '../explore/widgets/category_card.dart';

class SubjectsScreen extends StatefulWidget {
  final bool showBackButton;
  const SubjectsScreen({super.key, this.showBackButton = true});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: AppColors.getTextColor(context)))
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Consumer<LocaleProvider>(
                              builder: (context, localeProvider, _) => Text(
                                AppStrings.get(
                                    'categories_title', localeProvider.locale),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextColor(context),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.getMutedTextColor(context).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: widget.showBackButton
                ? IconButton(
                    icon: Icon(
                      Provider.of<LocaleProvider>(context, listen: false)
                                  .locale ==
                              'ar'
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      color: AppColors.getTextColor(context),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : SizedBox(width: 48, height: 48),
          ),
          Expanded(
            child: Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) => Text(
                AppStrings.get('categories_title', localeProvider.locale),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_categories.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(Icons.category_outlined,
                  size: 64,
                  color: AppColors.getTextColor(context).withOpacity(0.3)),
              SizedBox(height: 16),
              Text(
                AppStrings.get('no_categories', 
                    Provider.of<LocaleProvider>(context, listen: false).locale),
                style: TextStyle(
                  color: AppColors.getTextColor(context, secondary: true),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 180,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return CategoryCard(
          category: category,
          onTap: () {
            context.go('/courses?categoryId=${category.id}');
          },
        );
      },
    );
  }
}
