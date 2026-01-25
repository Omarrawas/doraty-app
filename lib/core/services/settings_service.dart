import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyLanguage = 'language';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyAutoDownload = 'auto_download';
  static const String _keyVideoQuality = 'video_quality';
  static const String _keyWifiOnly = 'wifi_only';
  static const String _keyGeminiApiKey = 'gemini_api_key';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  // Auto Download
  bool getAutoDownload() {
    return _prefs.getBool(_keyAutoDownload) ?? false;
  }

  Future<void> setAutoDownload(bool enabled) async {
    await _prefs.setBool(_keyAutoDownload, enabled);
  }

  // Video Quality
  String getVideoQuality() {
    return _prefs.getString(_keyVideoQuality) ?? 'عالية';
  }

  Future<void> setVideoQuality(String quality) async {
    await _prefs.setString(_keyVideoQuality, quality);
  }

  // WiFi Only
  bool getWifiOnly() {
    return _prefs.getBool(_keyWifiOnly) ?? true;
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _prefs.setBool(_keyWifiOnly, enabled);
  }
  
  // Gemini API Key
  String? getGeminiApiKey() {
    return _prefs.getString(_keyGeminiApiKey);
  }

  Future<void> setGeminiApiKey(String? key) async {
    if (key == null) {
      await _prefs.remove(_keyGeminiApiKey);
    } else {
      await _prefs.setString(_keyGeminiApiKey, key);
    }
  }
}
