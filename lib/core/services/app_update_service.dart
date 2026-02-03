import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateService {
  static const String _keyLastUpdateCheck = 'last_update_check';
  static const String _updateCheckUrl = 'https://cstlqyjoflhxtocrtypg.supabase.co/functions/v1/check-update';
  
  /// Check for app updates and show dialog if available
  Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_keyLastUpdateCheck);
      final now = DateTime.now();
      
      // Check only once per day unless forced
      if (lastCheck != null && !showNoUpdateDialog) {
        final lastCheckDate = DateTime.parse(lastCheck);
        if (now.difference(lastCheckDate).inHours < 24) {
          return;
        }
      }
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Check for updates from your server
      final response = await http.get(
        Uri.parse(_updateCheckUrl),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final downloadUrl = data['download_url'] as String;
        final updateNotes = data['notes'] as String?;
        
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
            );
          }
        } else if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أنت تستخدم أحدث إصدار من التطبيق')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحقق من التحديثات: $e')),
        );
      }
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
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 12),
            Text('تحديث متاح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار الجديد: $latestVersion',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (updateNotes != null) ...[
              const SizedBox(height: 12),
              const Text(
                'ما الجديد:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(updateNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('تحميل الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
