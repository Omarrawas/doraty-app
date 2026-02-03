import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../models/category_model.dart';
import '../../widgets/dynamic_gradient_background.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

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
            content: Text('خطأ في تحميل التصنيفات: $e'),
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
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            return _buildCategoryCard(cat);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة تصنيف'),
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
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

  Widget _buildCategoryCard(CategoryModel cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: cat.iconUrl != null
                    ? Image.network(cat.iconUrl!,
                        width: 24,
                        height: 24,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.category, color: Colors.white))
                    : const Icon(Icons.category, color: Colors.white),
              ),
              title: Text(
                cat.name,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                cat.slug,
                style: TextStyle(
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: Colors.blueAccent),
                    onPressed: () => _showAddEditDialog(category: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: () => _deleteCategory(cat.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog({CategoryModel? category}) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final slugController = TextEditingController(text: category?.slug ?? '');
    final iconController = TextEditingController(text: category?.iconUrl ?? '');

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
                decoration: const InputDecoration(labelText: 'اسم التصنيف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slugController,
                decoration: const InputDecoration(labelText: 'المعرف (Slug)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'رابط الأيقونة (اختياري)'),
              ),
               // Note: Parent selection omitted for brevity, can be added if needed
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('الرجاء ملء الحقول المطلوبة')),
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
                  );
                } else {
                  await _db.createCategory(
                    name: nameController.text,
                    slug: slugController.text,
                    iconUrl: iconController.text.isEmpty ? null : iconController.text,
                  );
                }
                _loadCategories(); // Refresh
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا التصنيف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم', style: TextStyle(color: Colors.red))),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            setState(() => _isLoading = false);
         }
      }
    }
  }
}
