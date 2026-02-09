import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../theme/app_colors.dart';
import 'dart:ui';

class AppUpdateService {
  static const String _keyLastUpdateCheck = 'last_update_check';

  /// Check for app updates and show dialog if available
  Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateDialog = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_keyLastUpdateCheck);
      final now = DateTime.now();

      // Check only once per day unless forced/manual check
      if (lastCheck != null && !showNoUpdateDialog) {
        final lastCheckDate = DateTime.parse(lastCheck);
        if (now.difference(lastCheckDate).inHours < 24) {
          return;
        }
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Check for updates from Supabase table 'app_updates'
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

        // Save last check time
        await prefs.setString(_keyLastUpdateCheck, now.toIso8601String());

        // Compare versions
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
            const SnackBar(
                content: Text('أنت تستخدم أحدث إصدار من التطبيق'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
  
  /// Compare version strings (e.g., "1.2.3" vs "1.2.4")
  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    
    return false;
  }
  
  /// Show update dialog
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
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primaryPurple,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تحديث جديد متاح',
                  style: TextStyle(
                    color: Colors.white,
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
                    color: Colors.white.withOpacity(0.8),
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
                if (updateNotes != null && updateNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ما الجديد:',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          updateNotes,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
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
                      color: Colors.white.withOpacity(0.5),
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
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
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
