import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';
import '../theme/app_colors.dart';
import 'dart:ui';
import 'dart:io';

class AppUpdateService {
  static const String _keyLastUpdateCheck = 'last_update_check';

  /// Check for app updates
  Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateDialog = false}) async {
    try {
      // 1. Handle Android (In-App Update via Google Play)
      if (!kIsWeb && Platform.isAndroid) {
        await _checkAndroidUpdate(context);
        return;
      }

      // 2. Handle Other Platforms (Existing Supabase logic for Windows/Web)
      await _checkGeneralUpdate(context, showNoUpdateDialog: showNoUpdateDialog);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  /// Special logic for Android using Google Play In-App Updates
  Future<void> _checkAndroidUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // If the update is important (priority >= 4), force immediate update
        if (info.updatePriority >= 4 || info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } 
        // Otherwise, allow flexible update (download in background)
        else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // After downloading, we prompt to complete
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Android In-App Update failed: $e');
      // Fallback to general update if Play Store check fails
      if (context.mounted) {
        await _checkGeneralUpdate(context);
      }
    }
  }

  /// General update logic using Supabase (Windows, Web, etc.)
  Future<void> _checkGeneralUpdate(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_keyLastUpdateCheck);
      final now = DateTime.now();

      if (lastCheck != null && !showNoUpdateDialog) {
        final lastCheckDate = DateTime.parse(lastCheck);
        if (now.difference(lastCheckDate).inHours < 24) return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!SupabaseService.instance.isInitialized) {
        debugPrint('⏭️ Skipping update check: Supabase not initialized');
        return;
      }

      final response = await SupabaseService.instance.client
          .from('app_updates')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final latestVersion = response['version_name'] as String;
        final downloadUrl = response['download_url'] as String;
        final updateNotes = response['release_notes'] as String?;
        final isMandatory = response['is_mandatory'] as bool? ?? false;

        await prefs.setString(_keyLastUpdateCheck, now.toIso8601String());

        if (_isNewerVersion(currentVersion, latestVersion)) {
          if (context.mounted) {
            _showUpdateDialog(
              context,
              latestVersion: latestVersion,
              downloadUrl: downloadUrl,
              updateNotes: updateNotes,
              isMandatory: isMandatory,
            );
          }
        } else if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('أنت تستخدم أحدث إصدار من التطبيق'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('General update check failed: $e');
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      for (int i = 0; i < 3; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String downloadUrl,
    String? updateNotes,
    bool isMandatory = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => PopScope(
        canPop: !isMandatory,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Color(0xFF1A1A2E).withOpacity(0.9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primaryPurple,
                    size: 40,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'تحديث جديد متاح',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'يتوفر إصدار جديد من التطبيق ($latestVersion). يرجى التحديث للحصول على آخر المميزات والتحسينات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTextColor(context, secondary: true),
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
                if (updateNotes != null && updateNotes.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getMutedTextColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ما الجديد:',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          updateNotes,
                          style: TextStyle(
                            color: AppColors.getTextColor(context, secondary: true),
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'لاحقاً',
                    style: TextStyle(
                      color: AppColors.getTextColor(context, secondary: true),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'تحديث الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
