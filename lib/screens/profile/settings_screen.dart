// Settings screen for user profile
// Allows changing name, profile picture, branch, and theme (dark/light)

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // final DatabaseService _dbService = DatabaseService(); // unused
  final ImagePicker _picker = ImagePicker();

  String? _name;
  String? _branch; // e.g., "علمي" أو "أدبي"
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
        _branch = user.userMetadata?['branch'] as String? ?? '';
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
    // Update Supabase user metadata (name & branch)
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null) {
      final updates = <String, dynamic>{};
      if (_name != null) updates['full_name'] = _name;
      if (_branch != null) updates['branch'] = _branch;
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
              .showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
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
            // Branch selector
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'الفرع',
                border: OutlineInputBorder(),
              ),
              value: _branch?.isNotEmpty == true ? _branch : null,
              items: const [
                DropdownMenuItem(value: 'علمي', child: Text('علمي')),
                DropdownMenuItem(value: 'أدبي', child: Text('أدبي')),
              ],
              onChanged: (v) => setState(() => _branch = v),
            ),
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
