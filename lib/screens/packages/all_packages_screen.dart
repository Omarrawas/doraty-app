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
    setState(() => _isLoading = true);
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
    String t(String key) => AppStrings.get(key, locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('all_bundles')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search & Filter Bar
              Padding(
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '${t('searching')}...',
                            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                            border: InputBorder.none,
                            icon: const Icon(Icons.search, color: Colors.white54),
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
                      ),
                      child: const Icon(Icons.filter_list, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Packages List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _bundles.isEmpty
                        ? Center(child: Text(t('no_courses_found'), style: const TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _bundles.length,
                            itemBuilder: (context, index) {
                              return BundleCard(
                                bundle: _bundles[index],
                                heroTag: 'all_bundles_list_${_bundles[index].id}',
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
}
