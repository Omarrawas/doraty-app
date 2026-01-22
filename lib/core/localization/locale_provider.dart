import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class LocaleProvider with ChangeNotifier {
  String _locale = 'ar';
  final SettingsService _settingsService = SettingsService();

  LocaleProvider() {
    _loadLocale();
  }

  String get locale => _locale;
  
  Locale get flutterLocale => Locale(_locale, _locale == 'ar' ? 'SY' : 'US');

  bool get isRtl => _locale == 'ar';

  void _loadLocale() {
    _locale = _settingsService.getLanguage();
    notifyListeners();
  }

  Future<void> setLocale(String lang) async {
    if (_locale == lang) return;
    
    _locale = lang;
    await _settingsService.setLanguage(lang);
    notifyListeners();
  }
}
