import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../models/category_model.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  String _t(String key) => AppStrings.get(key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getCategories();
      if (mounted) {
        setState(() {
          _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                      : Builder(
                          builder: (context) {
                            final parents = _categories.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
                            if (parents.isEmpty && _categories.isNotEmpty) {
                               // Fallback if some categories don't have parents but are standalone
                               parents.addAll(_categories);
                            }
                            return ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: parents.length,
                              itemBuilder: (context, index) {
                                final parent = parents[index];
                                final children = _categories.where((c) => c.parentId == parent.id).toList();
                                return _buildCategoryGroup(parent, children);
                              },
                            );
                          }
                        ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: Icon(Icons.add),
          label: Text(_t('add_category')),
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _t('categories_management'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(CategoryModel parent, List<CategoryModel> children) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Parent Header - More Compact
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.12),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.getGlassColor(context, opacity: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: parent.iconUrl != null && parent.iconUrl!.isNotEmpty
                            ? Image.network(parent.iconUrl!,
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.category, size: 20, color: AppColors.getTextColor(context)))
                            : Icon(Icons.category, size: 20, color: AppColors.getTextColor(context)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${_t('base_category')} (${parent.slug})',
                              style: TextStyle(
                                color: AppColors.getTextColor(context).withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        icon: Icon(Icons.edit_rounded, size: 18, color: Colors.blueAccent),
                        onPressed: () => _showAddEditDialog(category: parent),
                      ),
                      IconButton(
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        onPressed: () => _deleteCategory(parent.id),
                      ),
                    ],
                  ),
                ),
                
                // Children Categories Grid
                if (children.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_t('sub_categories')}:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context).withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: children.map((child) => _buildChildChip(child)).toList(),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      _t('no_sub_categories'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextColor(context).withOpacity(0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildChip(CategoryModel child) {
    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 180 : (MediaQuery.of(context).size.width - 64) / 2,
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.getGlassColor(context, opacity: 0.15),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: child.iconUrl != null && child.iconUrl!.isNotEmpty
                ? Image.network(child.iconUrl!, width: 14, height: 14, errorBuilder: (_, __, ___) => Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.getTextColor(context)))
                : Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.getTextColor(context)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  child.slug,
                  style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.5),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                onPressed: () => _showAddEditDialog(category: child),
              ),
              SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.delete, size: 16, color: Colors.redAccent),
                onPressed: () => _deleteCategory(child.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditDialog({CategoryModel? category}) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final slugController = TextEditingController(text: category?.slug ?? '');
    final iconController = TextEditingController(text: category?.iconUrl ?? '');
    String? selectedParentId = category?.parentId;

    // Filter categories to avoid self-selection or deep nesting (if needed)
    final parentOptions = _categories.where((c) => c.id != category?.id).toList();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? _t('edit_category') : _t('add_new_category')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: _t('category_name')),
              ),
              SizedBox(height: 12),
              TextField(
                controller: slugController,
                decoration: InputDecoration(labelText: _t('slug_label')),
              ),
              SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: InputDecoration(labelText: _t('icon_url_optional')),
              ),
              DropdownButtonFormField<String?>(
                value: selectedParentId,
                decoration: InputDecoration(
                  labelText: _t('parent_category_optional'),
                  hintText: _t('main_category'),
                ),
                dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : Colors.white,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(_t('none_main_category'), style: TextStyle(color: Colors.grey)),
                  ),
                  ...parentOptions.map((c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name),
                  )),
                ],
                onChanged: (val) => selectedParentId = val,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(_t('please_fill_required_fields'))),
                 );
                 return;
              }
              
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                if (isEditing) {
                  await _db.updateCategory(
                    id: category.id,
                    name: nameController.text,
                    slug: slugController.text,
                    iconUrl: iconController.text.isEmpty ? null : iconController.text,
                    parentId: selectedParentId ?? '', // Signal null-out if empty-like logic used, or handle explicitly
                  );
                } else {
                  await _db.createCategory(
                    name: nameController.text,
                    slug: slugController.text,
                    iconUrl: iconController.text.isEmpty ? null : iconController.text,
                    parentId: selectedParentId,
                  );
                }
                _loadCategories(); // Refresh
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
                  );
                  setState(() => _isLoading = false);
                }
              }
            },
            child: Text(isEditing ? _t('save') : _t('add_new')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('confirm_delete_title')),
        content: Text(_t('delete_category_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('no'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('yes'), style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteCategory(id);
        _loadCategories();
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
            setState(() => _isLoading = false);
         }
      }
    }
  }
}
