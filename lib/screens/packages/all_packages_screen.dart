import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  List<Bundle> _bundles = [];
  bool _isLoading = true;

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
          _bundles = data.map((e) => Bundle.fromJson(e)).toList();
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

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final double screenWidth = MediaQuery.of(context).size.width;
    String t(String key) => AppStrings.get(key, locale);

    // Responsive grid settings
    int crossAxisCount = 1;
    double childAspectRatio = 2.0;
    
    if (screenWidth > 1400) {
      crossAxisCount = 4;
      childAspectRatio = 1.35;
    } else if (screenWidth > 1000) {
      crossAxisCount = 3;
      childAspectRatio = 1.4;
    } else if (screenWidth > 650) {
      crossAxisCount = 2;
      childAspectRatio = 1.5;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 2.3;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('all_bundles'), style: const TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search & Filter Bar (Constrained)
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
                              color: AppColors.getGlassColor(context, opacity: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: TextField(
                              style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
                              decoration: InputDecoration(
                                hintText: '${t('searching')}...',
                                hintStyle: TextStyle(
                                  color: AppColors.getTextColor(context).withOpacity(0.54), 
                                  fontSize: 14,
                                  fontFamily: 'Cairo'
                                ),
                                border: InputBorder.none,
                                icon: Icon(Icons.search, color: AppColors.getTextColor(context).withOpacity(0.54)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Icon(Icons.filter_list, color: AppColors.getTextColor(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Packages List (Constrained Grid)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _bundles.isEmpty
                        ? Center(child: Text(t('no_courses_found'), style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontFamily: 'Cairo')))
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 24,
                                ),
                                itemCount: _bundles.length,
                                itemBuilder: (context, index) {
                                  return BundleCard(
                                    bundle: _bundles[index],
                                    heroTag: 'all_bundles_list_${_bundles[index].id}',
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
