import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
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
    setState(() => _isLoading = true);
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    final locale = Provider.of<LocaleProvider>(context).locale;
    String t(String key) => AppStrings.get(key, locale);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t('bundle_details')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DynamicGradientBackground(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(padding: EdgeInsets.only(top: 100)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              AppColors.getGlassColor(context, opacity: 0.15),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _displayBundle.imageUrl != null &&
                                    _displayBundle.imageUrl!.isNotEmpty
                                ? Container(
                                    width: double.infinity,
                                    height: 180,
                                    margin: EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 10,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        _displayBundle.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          color: AppColors.secondaryGold
                                              .withOpacity(0.2),
                                          child: Icon(
                                            Icons.collections_bookmark,
                                            color: AppColors.secondaryGold,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryGold
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.collections_bookmark,
                                      color: AppColors.secondaryGold,
                                      size: 40,
                                    ),
                                  ),
                            SizedBox(height: 20),
                            Text(
                              _displayTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_stories,
                                    color: AppColors.getTextColor(context, secondary: true),
                                    size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '${_displayCourses.length} ${t('courses_count_bundle')}',
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context, secondary: true),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (_displayBundle.description != null) ...[
                              SizedBox(height: 20),
                              Text(
                                _displayBundle.description!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTextColor(context, secondary: true),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _handlePrimaryAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _hasBundleAccess
                                    ? 'أكمل'
                                    : '${t('subscribe_now_prefix')}${_displayBundle.getFormattedPrice(locale)}',
                                style: TextStyle(
                                  fontSize: 16,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            t('included_courses'),
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => CourseCard(
                          course: _displayCourses[index],
                          heroTag: 'package_course_${_displayCourses[index].id}',
                        ),
                        childCount: _displayCourses.length,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
