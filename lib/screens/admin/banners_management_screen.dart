import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../models/banner_ad.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/image_upload_service.dart'; // Added

class BannersManagementScreen extends StatefulWidget {
  const BannersManagementScreen({super.key});

  @override
  State<BannersManagementScreen> createState() => _BannersManagementScreenState();
}

class _BannersManagementScreenState extends State<BannersManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<BannerAd> _banners = [];
  bool _isLoading = true;
  bool _isUploading = false; // Added

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getBanners(forceRefresh: true);
      if (mounted) {
        setState(() {
          _banners = data.map((e) => BannerAd.fromJson(e)).toList();
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
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : _banners.isEmpty
                          ? Center(
                              child: Text(
                                'لا يوجد إعلانات حالياً',
                                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _banners.length,
                              itemBuilder: (context, index) {
                                final banner = _banners[index];
                                return _buildBannerCard(banner);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditBannerDialog(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة إعلان جديد'),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'إدارة الإعلانات والبنرات',
              style: TextStyle(
                fontSize: 22,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBanners,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BannerAd banner) {
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
              contentPadding: const EdgeInsets.all(16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  width: 80,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, e) => Container(
                    width: 80,
                    height: 60,
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    child: const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
              title: Text(
                banner.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'النوع: ${banner.type}',
                style: TextStyle(
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                    onPressed: () => _showAddEditBannerDialog(banner: banner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _deleteBanner(banner.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEditBannerDialog({BannerAd? banner}) async {
    final titleController = TextEditingController(text: banner?.title);
    final subtitleController = TextEditingController(text: banner?.subtitle);
    final imageUrlController = TextEditingController(text: banner?.imageUrl);
    final linkUrlController = TextEditingController(text: banner?.linkUrl);
    final targetIdController = TextEditingController(text: banner?.targetId);
    String selectedType = banner?.type ?? 'ad';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context),
          title: Text(banner == null ? 'إضافة إعلان جديد' : 'تعديل الإعلان'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('العنوان الرئيسي', titleController),
                _buildDialogField('العنوان الفرعي', subtitleController),
                Row(
                  children: [
                    Expanded(child: _buildDialogField('رابط الصورة', imageUrlController)),
                    IconButton(
                      icon: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.image_search, color: AppColors.primaryPurple),
                      onPressed: () => _pickAndUploadImage(imageUrlController, setDialogState),
                    ),
                  ],
                ),
                if (imageUrlController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrlController.text,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: AppColors.getSurfaceColor(context),
                  decoration: const InputDecoration(labelText: 'نوع الإعلان'),
                  items: ['ad', 'course', 'package', 'external'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                if (selectedType == 'course' || selectedType == 'package')
                  _buildDialogField('المعرف (Target ID)', targetIdController),
                if (selectedType == 'external')
                  _buildDialogField('رابط خارجي', linkUrlController),
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
                if (titleController.text.isEmpty || imageUrlController.text.isEmpty) return;
                
                try {
                  if (banner == null) {
                    await _db.createBanner(
                      title: titleController.text,
                      subtitle: subtitleController.text,
                      imageUrl: imageUrlController.text,
                      type: selectedType,
                      targetId: targetIdController.text.isEmpty ? null : targetIdController.text,
                      linkUrl: linkUrlController.text.isEmpty ? null : linkUrlController.text,
                    );
                  } else {
                    await _db.updateBanner(
                      id: banner.id,
                      title: titleController.text,
                      subtitle: subtitleController.text,
                      imageUrl: imageUrlController.text,
                      type: selectedType,
                      targetId: targetIdController.text.isEmpty ? null : targetIdController.text,
                      linkUrl: linkUrlController.text.isEmpty ? null : linkUrlController.text,
                    );
                  }
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                    _loadBanners();
                  }
                } catch (e) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
    );
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الإعلان؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteBanner(id);
        _loadBanners();
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _pickAndUploadImage(TextEditingController controller, StateSetter setDialogState) async {
    setDialogState(() => _isUploading = true);
    try {
      final imageService = ImageUploadService();
      final imageFile = await imageService.pickImage();
      
      if (imageFile != null) {
        final url = await imageService.uploadImageToGitHub(
          imageFile,
          folder: 'images/banners',
        );

        if (mounted) {
          setDialogState(() {
            controller.text = url;
            _isUploading = false;
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفع الصورة بنجاح'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        setDialogState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setDialogState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
