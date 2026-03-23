import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../subscription/payment_screen.dart';
import '../../models/bundle.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isRTL = locale == 'ar';
    String t(String key) => AppStrings.get(key, locale);
    final currencyLabel = isRTL ? 'ل.س' : 'SYP';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Dark theme as per screenshot
      appBar: AppBar(
        title: Text(
          isRTL ? 'محتوى السلة' : 'Basket Content',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      body: cart.items.isEmpty
          ? _buildEmptyCart(context, t)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemBuilder: (context, index) {
                      final item = cart.items.values.toList()[index];
                      return _buildProfessionalCartItem(context, item, cart, locale, isRTL, currencyLabel);
                    },
                  ),
                ),
                _buildTotalSummary(context, cart, t, locale, currencyLabel),
              ],
            ),
    );
  }

  Widget _buildProfessionalCartItem(BuildContext context, CartItem item, CartProvider cart, String locale, bool isRTL, String currencyLabel) {
    final formatter = NumberFormat('#,###.##');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Label, Title, Image, and Delete button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trash Icon on the far side
              IconButton(
                onPressed: () => cart.removeItem(item.id),
                icon: Icon(Icons.delete_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              // Title and Label
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.isBundle ? (isRTL ? 'باقة' : 'Bundle') : (isRTL ? 'دورة' : 'Course'),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                    Text(
                      item.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
                    : Container(width: 60, height: 60, color: Colors.white10),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Course list if it's a bundle
          if (item.isBundle && item.originalObject is Bundle)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 12),
              child: Column(
                children: (item.originalObject as Bundle).courses.map((course) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatter.format(course.price),
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          course.title,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          if (item.isBundle) const Divider(color: Colors.white10, height: 24),

          // Pricing Breakdown (as per screenshot)
          _buildPriceRow(isRTL ? 'السعر' : 'Price', '$currencyLabel ${formatter.format(item.originalPrice)}', isWhite: true),
          if (item.discountAmount > 0)
            _buildPriceRow(isRTL ? 'خصم' : 'Discount', '$currencyLabel ${formatter.format(item.discountAmount)}-', isRed: true),
          _buildPriceRow(isRTL ? 'المجموع' : 'Subtotal', '$currencyLabel ${formatter.format(item.price)}', isBold: true),
          
          if (cart.items.values.toList().indexOf(item) < cart.items.length - 1)
             const Padding(
               padding: EdgeInsets.only(top: 16),
               child: Divider(color: Colors.white10, height: 1),
             ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isRed = false, bool isBold = false, bool isWhite = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: TextStyle(
              color: isRed ? Colors.redAccent : (isWhite || isBold ? Colors.white : Colors.white70),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, String Function(String) t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          Text(
            t('empty_cart_msg'),
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(t('browse_courses'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary(BuildContext context, CartProvider cart, String Function(String) t, String locale, String currencyLabel) {
    final formatter = NumberFormat('#,###.##');
    final isRTL = locale == 'ar';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currencyLabel ${formatter.format(cart.totalAmount)}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                isRTL ? 'المبلغ الإجمالي' : 'Total Amount',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(isRTL ? 'المجموع' : 'Subtotal', '$currencyLabel ${formatter.format(cart.totalAmount)}'),
          const SizedBox(height: 12),
          Align(
            alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                // Future: Discount Code Logic
              },
              child: Text(
                isRTL ? 'إضافة رمز الخصم' : 'Add Discount Code',
                style: const TextStyle(color: Color(0xFF6A6BB2), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (cart.items.isNotEmpty) {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(
                      amount: cart.totalAmount,
                      title: isRTL ? 'إتمام عملية التسجيل' : 'Complete Registration',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF434775), // Color from screenshot
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.credit_card_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  isRTL ? 'إتمام عملية التسجيل' : 'Complete Registration',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 14)),
      ],
    );
  }
}


