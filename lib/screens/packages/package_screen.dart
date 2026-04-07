import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/bundle.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/database_service.dart';

class PackageScreen extends StatefulWidget {
  final String packageTitle;
  final List<Course> courses;
  final String? bundleId;
  final Bundle? bundle;

  const PackageScreen({
    super.key,
    this.packageTitle = '',
    this.courses = const [],
    this.bundleId,
    this.bundle,
  });

  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Bundle? _loadedBundle;
  bool _isLoading = false;
  bool _hasBundleAccess = false;

  Bundle get _displayBundle =>
      widget.bundle ??
      _loadedBundle ??
      Bundle(
        id: widget.bundleId ?? 'temp',
        title: widget.packageTitle,
        courses: widget.courses,
        price: widget.courses.fold(0.0, (sum, c) => sum + c.price),
        discountPercentage: 20,
      );

  List<Course> get _displayCourses =>
      _loadedBundle?.courses ?? widget.courses;

  String get _displayTitle =>
      _loadedBundle?.title ?? widget.packageTitle;

  @override
  void initState() {
    super.initState();
    if (widget.bundle == null && widget.bundleId != null) {
      _loadBundleDetails();
    } else {
      _checkBundleAccess();
    }
  }

  Future<void> _loadBundleDetails() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _databaseService.getBundleById(widget.bundleId!);
      if (mounted && data != null) {
        setState(() {
          _loadedBundle = Bundle.fromJson(data);
          _isLoading = false;
        });
        _checkBundleAccess();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading bundle details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBundleAccess() async {
    try {
      final coursesToCheck = _displayCourses.map((c) => c.id).toList();
      if (coursesToCheck.isEmpty) return;
      
      final hasAccess = await _databaseService.hasBundleAccess(coursesToCheck);
      if (mounted) {
        setState(() => _hasBundleAccess = hasAccess);
      }
    } catch (e) {
      debugPrint('Error checking bundle access: $e');
    }
  }

  void _handlePrimaryAction() {
    if (_hasBundleAccess && _displayCourses.isNotEmpty) {
      final identifier = _displayCourses.first.slug.isNotEmpty ? _displayCourses.first.slug : _displayCourses.first.id;
      context.push('/course/$identifier');
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(
      id: _displayBundle.id,
      title: _displayBundle.title,
      price: _displayBundle.discountedPrice,
      originalPrice: _displayBundle.price,
      discountAmount: _displayBundle.price - _displayBundle.discountedPrice,
      imageUrl: _displayBundle.imageUrl,
      isBundle: true,
      originalObject: _displayBundle,
    );
    context.push('/cart');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    final locale = Provider.of<LocaleProvider>(context).locale;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMediumScreen = screenWidth > 600;
    
    String t(String key) => AppStrings.get(key, locale);

    return Scaffold(
      body: DynamicGradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  title: Text(t('bundle_details'), style: const TextStyle(fontFamily: 'Cairo')),
                  centerTitle: true,
                  backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.6),
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () async {
                        final bundle = _displayBundle;
                        final identifier = bundle.slug.isNotEmpty ? bundle.slug : bundle.id;
                        final String packageUrl = Uri.encodeFull('https://doraty-app.vercel.app/package/$identifier');
                        
                        final String shareText = locale == 'ar' 
                            ? 'تحقق من هذه الباقة في أكاديمية دوراتي: ${bundle.title}\n$packageUrl'
                            : 'Check out this package on Doraty Academy: ${bundle.title}\n$packageUrl';
                        
                        await Share.share(shareText);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.getGlassColor(context, opacity: 0.15),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_displayBundle.imageUrl != null && _displayBundle.imageUrl!.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  height: isMediumScreen ? 250 : 180,
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 15,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.network(
                                      _displayBundle.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        color: AppColors.secondaryGold.withOpacity(0.2),
                                        child: const Icon(
                                          Icons.collections_bookmark,
                                          color: AppColors.secondaryGold,
                                          size: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryGold.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.collections_bookmark,
                                    color: AppColors.secondaryGold,
                                    size: 48,
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Text(
                                _displayTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: isMediumScreen ? 32 : 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_stories,
                                      color: AppColors.getTextColor(context, secondary: true),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_displayCourses.length} ${t('courses_count_bundle')}',
                                    style: TextStyle(
                                      color: AppColors.getTextColor(context, secondary: true),
                                      fontSize: 16,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                              if (_displayBundle.description != null) ...[
                                const SizedBox(height: 24),
                                Text(
                                  _displayBundle.description!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context, secondary: true),
                                    fontSize: 16,
                                    height: 1.6,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _handlePrimaryAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 60),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 8,
                                  shadowColor: AppColors.primaryPurple.withOpacity(0.4),
                                ),
                                child: Text(
                                  _hasBundleAccess
                                      ? 'أكمل'
                                      : '${t('subscribe_now_prefix')}${_displayBundle.getFormattedPrice(locale)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          t('included_courses'),
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => CourseCard(
                        course: _displayCourses[index],
                        heroTag: 'package_course_${_displayCourses[index].id}',
                      ),
                      childCount: _displayCourses.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400, // Maximum card width to allow columns
                      mainAxisExtent: 330,     // Enforce strict vertical height to avoid overlaps
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
