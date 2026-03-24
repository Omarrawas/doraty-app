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

class CategoriesManagementScreen extends StatefulWidget {
  CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

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
          label: Text('إضافة تصنيف'),
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
              'إدارة التصنيفات',
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
      margin: EdgeInsets.only(bottom: 24),
      elevation: 0,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Parent Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.15),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.getGlassColor(context, opacity: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: parent.iconUrl != null && parent.iconUrl!.isNotEmpty
                            ? Image.network(parent.iconUrl!,
                                width: 24,
                                height: 24,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.category, color: AppColors.getTextColor(context)))
                            : Icon(Icons.category, color: AppColors.getTextColor(context)),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'التصنيف الأساسي (${parent.slug})',
                              style: TextStyle(
                                color: AppColors.getTextColor(context).withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_rounded, color: Colors.blueAccent),
                        onPressed: () => _showAddEditDialog(category: parent),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _deleteCategory(parent.id),
                      ),
                    ],
                  ),
                ),
                
                // Children Categories Grid
                if (children.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التصنيفات الفرعية:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context).withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: children.map((child) => _buildChildChip(child)).toList(),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'لا توجد تصنيفات فرعية',
                      style: TextStyle(
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
      width: MediaQuery.of(context).size.width > 600 ? 250 : double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getGlassColor(context, opacity: 0.2),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child.iconUrl != null && child.iconUrl!.isNotEmpty
                ? Image.network(child.iconUrl!, width: 16, height: 16, errorBuilder: (_, __, ___) => Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.getTextColor(context)))
                : Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.getTextColor(context)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  child.slug,
                  style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.6),
                    fontSize: 11,
                  ),
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
                icon: Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                onPressed: () => _showAddEditDialog(category: child),
              ),
              SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.delete, size: 18, color: Colors.redAccent),
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
        title: Text(isEditing ? 'تعديل التصنيف' : 'إضافة تصنيف جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'اسم التصنيف'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: slugController,
                decoration: InputDecoration(labelText: 'المعرف (Slug)'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: InputDecoration(labelText: 'رابط الأيقونة (اختياري)'),
              ),
              DropdownButtonFormField<String?>(
                value: selectedParentId,
                decoration: InputDecoration(
                  labelText: 'التصنيف الأب (اختياري)',
                  hintText: 'تصنيف رئيسي',
                ),
                dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : Colors.white,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('بدون (تصنيف رئيسي)', style: TextStyle(color: Colors.grey)),
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
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('الرجاء ملء الحقول المطلوبة')),
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
            child: Text(isEditing ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا التصنيف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('لا')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('نعم', style: TextStyle(color: Colors.red))),
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
