// Settings screen for user profile
// Allows changing name, profile picture, and theme (dark/light)

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/supabase_service.dart';

import '../../core/utils/error_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // final DatabaseService _dbService = DatabaseService(); // unused
  final ImagePicker _picker = ImagePicker();

  String? _name;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseService.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _name = user.userMetadata?['full_name'] as String? ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    // Update Supabase user metadata (name)
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null) {
      final updates = <String, dynamic>{};
      if (_name != null) updates['full_name'] = _name;
      // Note: image upload is omitted for brevity – you would upload to storage and save URL.
      try {
        await SupabaseService.instance.client
            .from('users')
            .update(updates)
            .eq('id', userId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: _imageFile != null
                      ? FileImage(File(_imageFile!.path))
                      : null,
                  child: _imageFile == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Name field
            TextField(
              decoration: const InputDecoration(
                labelText: 'الاسم',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _name),
              onChanged: (v) => _name = v,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            // Theme toggle
            SwitchListTile(
              title: const Text('الوضع الليلي'),
              value: isDark,
              onChanged: (_) async {
                await themeProvider.toggleTheme();
              },
            ),
            const SizedBox(height: 30),
            // Save button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
