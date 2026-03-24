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
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                      : _banners.isEmpty
                          ? Center(
                              child: Text(
                                'لا يوجد إعلانات حالياً',
                                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(20),
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
          icon: Icon(Icons.add),
          label: Text('إضافة إعلان جديد'),
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
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 16),
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
            icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
            onPressed: _loadBanners,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BannerAd banner) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
              contentPadding: EdgeInsets.all(16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  width: 80,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.getTextColor(context).withOpacity(0.10)),
                  errorWidget: (context, url, e) => Container(
                    width: 80,
                    height: 60,
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    child: Icon(Icons.broken_image, color: AppColors.getTextColor(context)),
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'النوع: ${banner.type}',
                    style: TextStyle(
                      color: AppColors.getTextColor(context).withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'المكان: ${banner.location == 'top' ? 'علوي' : 'سفلي'}',
                    style: TextStyle(
                      color: AppColors.primaryPurple.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: Colors.blueAccent),
                    onPressed: () => _showAddEditBannerDialog(banner: banner),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
    String selectedLocation = banner?.location ?? 'top';

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
                // PREVIEW SECTION
                Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.getMutedTextColor(context),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معاينة الإعلان:', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60), fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      _buildPreviewItem(
                        BannerAd(
                          id: '',
                          title: titleController.text,
                          subtitle: subtitleController.text,
                          imageUrl: imageUrlController.text,
                          type: selectedType,
                          location: selectedLocation,
                          createdAt: DateTime.now(),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDialogField('العنوان الرئيسي', titleController, (val) => setDialogState(() {})),
                _buildDialogField('العنوان الفرعي / نص زر التفاعل (اختياري)', subtitleController, (val) => setDialogState(() {})),
                Row(
                  children: [
                    Expanded(child: _buildDialogField('رابط الصورة', imageUrlController, (val) => setDialogState(() {}))),
                    IconButton(
                      icon: _isUploading 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.image_search, color: AppColors.primaryPurple),
                      onPressed: () => _pickAndUploadImage(imageUrlController, setDialogState),
                    ),
                  ],
                ),
                if (imageUrlController.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrlController.text,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SizedBox.shrink(),
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: AppColors.getSurfaceColor(context),
                  decoration: InputDecoration(labelText: 'نوع الإعلان'),
                  items: ['ad', 'course', 'package', 'external'].map((type) {
                    String label = type;
                    if (type == 'ad') label = 'إعلان عام';
                    if (type == 'course') label = 'كورس محدد';
                    if (type == 'package') label = 'باقة / عرض';
                    if (type == 'external') label = 'رابط خارجي';
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        // Clear target if type changed
                        if (selectedType != (banner?.type ?? '')) {
                          targetIdController.clear();
                        }
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                if (selectedType == 'course')
                  _buildTargetSelector(
                    label: 'اختر الكورس',
                    targetId: targetIdController.text,
                    type: 'course',
                    onSelected: (String id, String name, String? imageUrl) {
                      setDialogState(() {
                        targetIdController.text = id;
                        if (imageUrlController.text.isEmpty && imageUrl != null) {
                          imageUrlController.text = imageUrl;
                        }
                      });
                    },
                  )
                else if (selectedType == 'package')
                  _buildTargetSelector(
                    label: 'اختر الباقة',
                    targetId: targetIdController.text,
                    type: 'package',
                    onSelected: (String id, String name, String? imageUrl) {
                      setDialogState(() {
                        targetIdController.text = id;
                        if (imageUrlController.text.isEmpty && imageUrl != null) {
                          imageUrlController.text = imageUrl;
                        }
                      });
                    },
                  )
                else if (selectedType == 'external')
                  _buildDialogField('رابط خارجي', linkUrlController),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  dropdownColor: AppColors.getSurfaceColor(context),
                  decoration: InputDecoration(labelText: 'مكان الظهور'),
                  items: [
                    {'value': 'top', 'label': 'رئيسي (أعلى)'},
                    {'value': 'bottom', 'label': 'ثانوي (أسفل)'},
                  ].map((loc) {
                    return DropdownMenuItem(value: loc['value'], child: Text(loc['label']!));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedLocation = val);
                  },
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
                if (titleController.text.isEmpty || imageUrlController.text.isEmpty) return;
                
                try {
                  if (banner == null) {
                    await _db.createBanner(
                      title: titleController.text,
                      subtitle: subtitleController.text,
                      imageUrl: imageUrlController.text,
                      type: selectedType,
                      location: selectedLocation,
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
                      location: selectedLocation,
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
              child: Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, [Function(String)? onChanged]) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
        ),
      ),
    );
  }

  Widget _buildPreviewItem(BannerAd item) {
    if (item.location == 'bottom') {
      // Small landscape preview
      String? buttonText = item.subtitle;
      if ((buttonText == null || buttonText.isEmpty) && item.type == 'external') {
        buttonText = 'زيارة الرابط';
      }

      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                )
              else
                Container(color: Colors.black12, child: Icon(Icons.image, color: AppColors.getTextColor(context).withOpacity(0.24))),
              
              if (buttonText != null && buttonText.isNotEmpty)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(buttonText, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      // Large Top-style preview
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              if (item.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                )
              else
                Container(color: Colors.black12, height: double.infinity, width: double.infinity, child: Icon(Icons.image, color: AppColors.getTextColor(context).withOpacity(0.24))),
              
              // Gradient for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
              
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.subtitle != null && item.subtitle!.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(item.subtitle!, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 8)),
                      ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty ? 'عنوان الإعلان' : item.title,
                            style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.type == 'external' || (item.subtitle != null && item.subtitle!.isNotEmpty))
                          Icon(Icons.arrow_forward_rounded, color: AppColors.getTextColor(context), size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTargetSelector({
    required String label,
    required String targetId,
    required String type,
    required Function(String id, String name, String? imageUrl) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13)),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _openSearchDialog(type, onSelected),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Icon(
                  type == 'course' ? Icons.school_rounded : Icons.inventory_2_rounded,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    targetId.isEmpty ? 'انقر للاختيار...' : 'مُعرّف: $targetId',
                    style: TextStyle(
                      color: targetId.isEmpty ? Colors.white30 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.search, color: AppColors.getTextColor(context).withOpacity(0.70), size: 20),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  void _openSearchDialog(String type, Function(String id, String name, String? imageUrl) onSelected) async {
    showDialog(
      context: context,
      builder: (context) => _TargetSearchDialog(
        type: type,
        onSelected: (id, name, imageUrl) {
          onSelected(id, name, imageUrl);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا الإعلان؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('لا')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('نعم', style: TextStyle(color: Colors.red)),
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
              SnackBar(content: Text('تم رفع الصورة بنجاح'), backgroundColor: Colors.green),
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

class _TargetSearchDialog extends StatefulWidget {
  final String type;
  final Function(String id, String name, String? imageUrl) onSelected;

  const _TargetSearchDialog({required this.type, required this.onSelected});

  @override
  State<_TargetSearchDialog> createState() => _TargetSearchDialogState();
}

class _TargetSearchDialogState extends State<_TargetSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  List<dynamic> _items = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      if (widget.type == 'course') {
        final data = await _db.getCourses(forceRefresh: true);
        _items = data;
      } else {
        final data = await _db.getBundles(forceRefresh: true);
        _items = data;
      }
      _filteredItems = _items;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        final title = item['title'].toString().toLowerCase();
        final instructor = item['instructor_name']?.toString().toLowerCase() ?? '';
        return title.contains(query) || instructor.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF1E1E2C),
      title: Text(widget.type == 'course' ? 'اختر الكورس' : 'اختر الباقة'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو اسم المعلم...',
                hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.30)),
                prefixIcon: Icon(Icons.search, color: AppColors.getTextColor(context).withOpacity(0.70)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: AppColors.getTextColor(context)),
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
            else
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.30))))
                    : ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item['image_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: item['image_url'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(width: 40, height: 40, color: AppColors.getTextColor(context).withOpacity(0.10)),
                            ),
                            title: Text(item['title'] ?? '', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14)),
                            subtitle: Text(
                              item['instructor_name'] ?? (widget.type == 'package' ? 'باقة' : ''),
                              style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 12),
                            ),
                            onTap: () => widget.onSelected(item['id'], item['title'], item['image_url']),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إغلاق')),
      ],
    );
  }
}
