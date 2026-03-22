import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _shouldFocusSearch = false;

  int get currentIndex => _currentIndex;
  bool get shouldFocusSearch => _shouldFocusSearch;

  void setIndex(int index, {bool focusSearch = false}) {
    _currentIndex = index;
    _shouldFocusSearch = focusSearch;
    notifyListeners();
  }

  void consumeSearchFocus() {
    _shouldFocusSearch = false;
    notifyListeners();
  }
}
