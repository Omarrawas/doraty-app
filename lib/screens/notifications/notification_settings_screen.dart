import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  Map<String, bool> _preferences = {
    'email_marketing': true,
    'push_learning': true,
    'push_social': true,
    'push_marketing': false,
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    try {
      final prefs = await _db.getNotificationPreferences(userId);
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    // Optimistic update
    setState(() {
      _preferences[key] = value;
    });

    try {
      await _db.updateNotificationPreferences(userId, _preferences);
    } catch (e) {
      debugPrint('Error updating preference: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _preferences[key] = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحديث الإعدادات')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'إعدادات الإشعارات',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader('إشعارات التطبيق'),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  'تعليمي',
                  'تذكيرات بالدروس، الامتحانات، والواجبات',
                  'push_learning',
                  Icons.school_outlined,
                ),
                _buildSwitchTile(
                  'اجتماعي',
                  'ردود على أسئلتك وتفاعلات المجتمع',
                  'push_social',
                  Icons.people_outline,
                ),
                _buildSwitchTile(
                  'عروض وتحديثات',
                  'أخبار المنصة وعروض خاصة',
                  'push_marketing',
                  Icons.local_offer_outlined,
                ),
                const Divider(height: 40),
                _buildSectionHeader('البريد الإلكتروني'),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  'نشرة بريدية',
                  'ملخص أسبوعي وعروض حصرية',
                  'email_marketing',
                  Icons.email_outlined,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryPurple,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String key,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        value: _preferences[key] ?? false,
        onChanged: (val) => _updatePreference(key, val),
        activeColor: AppColors.primaryPurple,
        title: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, right: 28),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
