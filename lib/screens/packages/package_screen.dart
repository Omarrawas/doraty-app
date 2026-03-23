import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/bundle.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../cart/cart_screen.dart';
import '../../core/providers/cart_provider.dart';

class PackageScreen extends StatelessWidget {
  final String packageTitle;
  final List<Course> courses;
  final Bundle? bundle; // Optional full bundle object

  const PackageScreen({
    super.key,
    required this.packageTitle,
    required this.courses,
    this.bundle,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    String t(String key) => AppStrings.get(key, locale);

    // If no bundle object is provided, create a dummy one for the price info
    final displayBundle = bundle ?? Bundle(
      id: 'temp',
      title: packageTitle,
      courses: courses,
      price: courses.fold(0.0, (sum, c) => sum + (c.price)),
      discountPercentage: 20, // Default discount for bundles
    );

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
                  const SliverPadding(padding: EdgeInsets.only(top: 100)),
                  
                  // Package Main Info Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.getGlassColor(context, opacity: 0.15),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Bundle Image or Icon
                            displayBundle.imageUrl != null && displayBundle.imageUrl!.isNotEmpty
                                ? Container(
                                    width: double.infinity,
                                    height: 180,
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        displayBundle.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: AppColors.secondaryGold.withOpacity(0.2),
                                          child: const Icon(Icons.collections_bookmark, 
                                              color: AppColors.secondaryGold, size: 40),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryGold.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.collections_bookmark, 
                                        color: AppColors.secondaryGold, size: 40),
                                  ),
                            const SizedBox(height: 20),
                            Text(
                              packageTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_stories, color: Colors.white.withOpacity(0.6), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${courses.length} ${t('courses_count_bundle')}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (displayBundle.description != null) ...[
                              const SizedBox(height: 20),
                              Text(
                                displayBundle.description!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Subscribe Button inside the card
                            ElevatedButton(
                              onPressed: () {
                                final cart = Provider.of<CartProvider>(context, listen: false);
                                cart.addItem(
                                  id: displayBundle.id,
                                  title: displayBundle.title,
                                  price: displayBundle.discountedPrice,
                                  originalPrice: displayBundle.price,
                                  discountAmount: displayBundle.price - displayBundle.discountedPrice,
                                  imageUrl: displayBundle.imageUrl,
                                  isBundle: true,
                                  originalObject: displayBundle,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CartScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '${t('subscribe_now_prefix')}${displayBundle.getFormattedPrice(locale)}',
                                style: const TextStyle(
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

                  // Divider/Label
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
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
                          const SizedBox(width: 12),
                          Text(
                            t('included_courses'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Courses Grid/List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: courses.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(Icons.info_outline, color: Colors.white24, size: 60),
                                  const SizedBox(height: 16),
                                  Text(
                                    t('no_courses_found'),
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final course = courses[index];
                                return CourseCard(
                                  course: course,
                                  heroTag: 'package_course_${course.id}',
                                );
                              },
                              childCount: courses.length,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 20,
                            ),
                          ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
