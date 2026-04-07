import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../subscription/payment_screen.dart';
import '../../models/bundle.dart';
import '../../widgets/dynamic_gradient_background.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isRTL = locale == 'ar';
    final currencyLabel = isRTL ? 'ل.س' : 'SYP';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppStrings.get('cart_content', locale),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: cart.items.isEmpty
              ? _buildEmptyCart(context, locale)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.items.length,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = cart.items.values.toList()[index];
                          return _buildPremiumCartItem(context, item, cart, locale, isRTL, currencyLabel);
                        },
                      ),
                    ),
                    _buildGlassTotalSummary(context, cart, locale, currencyLabel),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPremiumCartItem(BuildContext context, CartItem item, CartProvider cart, String locale, bool isRTL, String currencyLabel) {
    final formatter = NumberFormat('#,###.##');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isBundle ? AppStrings.get('bundle_badge', locale) : AppStrings.get('course', locale),
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              fontFamily: 'Cairo',
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: item.imageUrl != null
                              ? Image.network(item.imageUrl!, width: 75, height: 75, fit: BoxFit.cover)
                              : Container(
                                  width: 75,
                                  height: 75,
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  child: const Icon(Icons.image_not_supported_rounded, color: Colors.white24),
                                ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => cart.removeItem(item.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (item.isBundle && item.originalObject is Bundle) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white12),
                  ),
                  ...(item.originalObject as Bundle).courses.map((course) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryPurple.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              course.title,
                              style: TextStyle(
                                color: AppColors.getMutedTextColor(context),
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildPremiumPriceRow(context, AppStrings.get('price', locale), '$currencyLabel ${formatter.format(item.originalPrice)}'),
                      if (item.discountAmount > 0)
                        _buildPremiumPriceRow(context, AppStrings.get('discount', locale), '${formatter.format(item.discountAmount)}-', isRed: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      _buildPremiumPriceRow(
                        context,
                        AppStrings.get('subtotal', locale),
                        '$currencyLabel ${formatter.format(item.price)}',
                        isBold: true,
                        accentColor: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumPriceRow(BuildContext context, String label, String value, {bool isRed = false, bool isBold = false, Color? accentColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.getMutedTextColor(context),
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isRed ? Colors.redAccent : (accentColor ?? AppColors.getTextColor(context)),
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCart(BuildContext context, String locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryPurple.withOpacity(0.1),
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.primaryPurple.withOpacity(0.8)),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.get('empty_cart_msg', locale),
            style: TextStyle(
              fontSize: 20,
              color: AppColors.getTextColor(context),
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'أضف بعض الدورات لتبدأ رحلتك التعليمية',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.getMutedTextColor(context),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(AppStrings.get('browse_courses', locale), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTotalSummary(BuildContext context, CartProvider cart, String locale, String currencyLabel) {
    final formatter = NumberFormat('#,###.##');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.get('total_amount', locale),
                    style: TextStyle(
                      color: AppColors.getMutedTextColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    '$currencyLabel ${formatter.format(cart.totalAmount)}',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  if (cart.items.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          amount: cart.totalAmount,
                          title: AppStrings.get('complete_registration', locale),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: AppColors.primaryPurple.withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.get('complete_registration', locale),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
