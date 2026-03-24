import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyLanguage = 'language';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyGeminiApiKey = 'gemini_api_key';

  SharedPreferences? _prefs;
  late FlutterSecureStorage _secureStorage;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _secureStorage = const FlutterSecureStorage();
  }

  // Language
  String getLanguage() {
    final prefs = _prefs;
    if (prefs == null) return 'ar';
    return prefs.getString(_keyLanguage) ?? 'ar';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_keyLanguage, lang);
  }

  // Notifications
  bool getNotificationsEnabled() {
    final prefs = _prefs;
    if (prefs == null) return true;
    return prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_keyNotifications, enabled);
  }





  
  // Gemini API Key (Stored Securely)
  Future<String?> getGeminiApiKey() async {
    return await _secureStorage.read(key: _keyGeminiApiKey);
  }
  
  Future<void> setGeminiApiKey(String? key) async {
    if (key == null) {
      await _secureStorage.delete(key: _keyGeminiApiKey);
    } else {
      await _secureStorage.write(key: _keyGeminiApiKey, value: key);
    }
  }
}
