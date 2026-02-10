import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'supabase_service.dart';

/// Service to manage screen security (prevent screenshots and screen recording)
class ScreenSecurityService {
  static final ScreenSecurityService _instance = ScreenSecurityService._internal();
  factory ScreenSecurityService() => _instance;
  ScreenSecurityService._internal();

  bool _isSecured = false;

  /// Check if screenshot protection is enabled in app settings
  Future<bool> isProtectionEnabled() async {
    try {
      final response = await SupabaseService.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'screenshot_protection_enabled')
          .maybeSingle();

      if (response == null) {
        // Default to enabled if setting doesn't exist
        return true;
      }

      final value = response['setting_value'] as String?;
      return value?.toLowerCase() == 'true';
    } catch (e) {
      debugPrint('⚠️ Error checking protection setting: $e');
      // Default to enabled on error for security
      return true;
    }
  }

  /// Enable screenshot and screen recording protection
  /// This should be called for non-admin users (if protection is enabled)
  Future<void> enableScreenSecurity() async {
    // Always try to enable, don't rely solely on valid state
    try {
      // Only works on Android
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        _isSecured = true;
        debugPrint('✅ Screen security enabled - Screenshots blocked');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to enable screen security: $e');
    }
  }

  /// Disable screenshot and screen recording protection
  /// This should be called for admin users or when protection is disabled globally
  Future<void> disableScreenSecurity() async {
    // Always try to disable, don't rely solely on valid state
    try {
      // Only works on Android
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        _isSecured = false;
        debugPrint('✅ Screen security disabled - Screenshots allowed');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to disable screen security: $e');
    }
  }

  /// Apply screen security based on user role and app settings
  /// Returns true if protection was applied, false otherwise
  Future<bool> applySecurityPolicy({required bool isAdmin}) async {
    // Admins always have screenshots allowed
    if (isAdmin) {
      await disableScreenSecurity();
      debugPrint('👑 Admin user - Screenshots allowed');
      return false;
    }

    // Check if protection is enabled in settings
    final protectionEnabled = await isProtectionEnabled();
    
    if (protectionEnabled) {
      await enableScreenSecurity();
      debugPrint('🔒 Regular user - Screenshots blocked (policy enabled)');
      return true;
    } else {
      await disableScreenSecurity();
      debugPrint('📸 Regular user - Screenshots allowed (policy disabled by admin)');
      return false;
    }
  }

  /// Check if screen security is currently enabled
  bool get isSecured => _isSecured;
}
