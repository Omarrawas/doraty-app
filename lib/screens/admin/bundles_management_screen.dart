import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../models/bundle.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import 'package:go_router/go_router.dart';

class BundlesManagementScreen extends StatefulWidget {
  const BundlesManagementScreen({super.key});

  @override
  State<BundlesManagementScreen> createState() => _BundlesManagementScreenState();
}

class _BundlesManagementScreenState extends State<BundlesManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Bundle> _bundles = [];
  bool _isLoading = true;

  String _t(String key) {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  Future<void> _loadBundles() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getBundles(forceRefresh: true);
      if (mounted) {
        setState(() {
          _bundles = data.map((e) => Bundle.fromJson(e)).toList();
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
                      : _bundles.isEmpty
                          ? Center(
                              child: Text(
                                _t('no_bundles_found_admin'),
                                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: _bundles.length,
                              itemBuilder: (context, index) {
                                final bundle = _bundles[index];
                                return _buildBundleCard(bundle);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await context.push('/admin/bundles/create');
            if (result == true) _loadBundles();
          },
          icon: Icon(Icons.add),
          label: Text(_t('add_new_bundle')),
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
              _t('bundles_management'),
              style: TextStyle(
                fontSize: 22,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
            onPressed: _loadBundles,
          ),
        ],
      ),
    );
  }

  Widget _buildBundleCard(Bundle bundle) {
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
                child: Image.network(
                  bundle.imageUrl ?? '',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    child: Icon(Icons.collections_bookmark, color: AppColors.getTextColor(context)),
                  ),
                ),
              ),
              title: Text(
                bundle.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    '${bundle.courses.length} ${_t('courses_count_bundle')} | ${bundle.price} ${_t('currency_syp')}',
                    style: TextStyle(
                      color: AppColors.getTextColor(context).withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: Colors.blueAccent),
                    onPressed: () async {
                      final result = await context.push(
                        '/admin/bundles/edit/${bundle.id}',
                        extra: bundle,
                      );
                      if (result == true) _loadBundles();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _deleteBundle(bundle.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBundle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('confirm_delete_title')),
        content: Text(_t('delete_bundle_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('no'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('yes'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteBundle(id);
        _loadBundles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
