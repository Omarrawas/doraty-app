import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyLanguage = 'language';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyGeminiApiKey = 'gemini_api_key';

  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _secureStorage = const FlutterSecureStorage();
  }

  // Language
  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? 'ar';
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString(_keyLanguage, lang);
  }

  // Notifications
  bool getNotificationsEnabled() {
    return _prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotifications, enabled);
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
