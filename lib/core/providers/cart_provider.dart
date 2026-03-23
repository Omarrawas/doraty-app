import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String title;
  final double price; // Discounted/Final price
  final double originalPrice;
  final double discountAmount;
  final String? imageUrl;
  final bool isBundle;
  final dynamic originalObject;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.originalPrice,
    this.discountAmount = 0,
    this.imageUrl,
    this.isBundle = false,
    this.originalObject,
  });
}


class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price;
    });
    return total;
  }

  bool isItemInCart(String id) {
    return _items.containsKey(id);
  }

  void addItem({
    required String id,
    required String title,
    required double price,
    required double originalPrice,
    double discountAmount = 0,
    String? imageUrl,
    bool isBundle = false,
    dynamic originalObject,
  }) {
    if (_items.containsKey(id)) {
      return;
    } else {
      _items.putIfAbsent(
        id,
        () => CartItem(
          id: id,
          title: title,
          price: price,
          originalPrice: originalPrice,
          discountAmount: discountAmount,
          imageUrl: imageUrl,
          isBundle: isBundle,
          originalObject: originalObject,
        ),
      );
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.remove(id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
