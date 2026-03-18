import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/course.dart';
import '../../widgets/dynamic_gradient_background.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() =>
      _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState
    extends State<NotificationsManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  // Form Fields
  String _title = '';
  String _body = '';
  String _targetType = 'all'; // all, course, user
  String? _selectedTargetId;

  // Data for Dropdowns
  List<Course> _courses = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingData = false;

  // Sending State
  bool _isSending = false;

  // History
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCourses(); // Pre-load courses as they are commonly used
  }

  Future<void> _loadHistory() async {
    try {
      final response = await SupabaseService.instance.client
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(response);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final coursesData = await _db.getCourses();
      if (mounted) {
        setState(() {
          _courses = coursesData.map((data) => Course.fromJson(data)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoadingData = true);
    try {
      // Simple search by name or email
      final response = await SupabaseService.instance.client
          .from('users')
          .select('id, full_name, email')
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .limit(10);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_targetType != 'all' && _selectedTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المستهدف (كورس أو مستخدم)')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // 1. Record in Database (Admin Log)
      await SupabaseService.instance.client.from('admin_notifications').insert({
        'title': _title,
        'body': _body,
        'notification_type': _targetType,
        'target_id': _selectedTargetId,
        'sender_id': SupabaseService.instance.currentUserId,
      });

      // 2. Broadcast in-app notification (Direct DB insert)
      final userCount = await _db.broadcastNotification(
        title: _title,
        body: _body,
        targetType: _targetType,
        targetId: _selectedTargetId,
        category: 'announcement',
      );

      // 3. Trigger FCM Push Notification
      // Note: This is now handled automatically by a Supabase Database Webhook 
      // on the 'admin_notifications' table which triggers the 'send-push' edge function.
      // The direct call was redundant and used a mismatched slug.
      debugPrint('FCM push triggered automatically via DB webhook on admin_notifications');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الإرسال بنجاح إلى $userCount مستخدم'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _targetType = 'all';
          _selectedTargetId = null;
          _title = '';
          _body = '';
        });
        _loadHistory(); // Reload history
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildComposeSection(),
                        const SizedBox(height: 32),
                        Text(
                          'سجل الإشعارات المرسلة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildHistoryList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'إدارة الإشعارات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إرسال إشعار جديد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 24),

                // Target Type Dropdown
                _buildDropdown(
                  label: 'إرسال إلى',
                  value: _targetType,
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('جميع المستخدمين')),
                    DropdownMenuItem(
                        value: 'course', child: Text('طلاب دورة محددة')),
                    DropdownMenuItem(value: 'user', child: Text('مستخدم محدد')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _targetType = val!;
                      _selectedTargetId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Conditional Selection Fields
                if (_targetType == 'course')
                  _buildDropdown(
                    label: 'اختر الدورة',
                    value: _selectedTargetId,
                    items: _courses.map((course) {
                      return DropdownMenuItem(
                        value: course.id,
                        child:
                            Text(course.title, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTargetId = val),
                    validator: (val) =>
                        val == null ? 'يرجى اختيار الدورة' : null,
                  ),

                if (_targetType == 'user')
                  Column(
                    children: [
                      TextFormField(
                        style:
                            TextStyle(color: AppColors.getTextColor(context)),
                        decoration: _inputDecoration(
                          label: 'بحث عن مستخدم',
                          icon: Icons.search,
                          suffix: _isLoadingData
                              ? Transform.scale(
                                  scale: 0.5,
                                  child: const CircularProgressIndicator(
                                      color: Colors.white))
                              : null,
                        ),
                        onChanged: (val) {
                          if (val.length > 2) _searchUsers(val);
                        },
                      ),
                      if (_users.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final isSelected =
                                  _selectedTargetId == user['id'];
                              return ListTile(
                                title: Text(user['full_name'] ?? 'بدون اسم',
                                    style: TextStyle(
                                        color:
                                            AppColors.getTextColor(context))),
                                subtitle: Text(user['email'] ?? '',
                                    style: TextStyle(
                                        color: AppColors.getTextColor(context)
                                            .withOpacity(0.5))),
                                selected: isSelected,
                                selectedTileColor:
                                    Colors.white.withOpacity(0.1),
                                onTap: () {
                                  setState(() {
                                    _selectedTargetId = user['id'];
                                    _users = [];
                                  });
                                },
                                trailing: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.greenAccent)
                                    : null,
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: _inputDecoration(
                      label: 'عنوان الإشعار', icon: Icons.title),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'مطلوب' : null,
                  onSaved: (val) => _title = val!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: _inputDecoration(
                      label: 'نص الإشعار', icon: Icons.message),
                  maxLines: 3,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'مطلوب' : null,
                  onSaved: (val) => _body = val!,
                ),
                const SizedBox(height: 32),

                // Send Button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.grey[900],
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: _inputDecoration(label: label, icon: Icons.layers),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: AppColors.getTextColor(context).withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
            colors: [AppColors.primaryPurple, Colors.blueAccent]),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendNotification,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: Colors.white),
                  SizedBox(width: 8),
                  Text('إرسال الإشعار',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.normal)),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_history.isEmpty) {
      return Center(
        child: Text('لا يوجد سجل للإشعارات',
            style: TextStyle(
                color: AppColors.getTextColor(context).withOpacity(0.5))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getTypeColor(item['notification_type'])
                          .withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getTypeIcon(item['notification_type']),
                        color: _getTypeColor(item['notification_type']),
                        size: 20),
                  ),
                  title: Text(
                    item['title'] ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: AppColors.getTextColor(context)),
                  ),
                  subtitle: Text(
                    '${item['body']}\n${_formatDate(item['created_at'])}',
                    style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.6),
                        fontSize: 13),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(item['notification_type'])
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _getTypeColor(item['notification_type'])
                              .withOpacity(0.4)),
                    ),
                    child: Text(
                      _getTypeLabel(item['notification_type']),
                      style: TextStyle(
                          fontSize: 10,
                          color: _getTypeColor(item['notification_type']),
                          fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'all':
        return Colors.blueAccent;
      case 'course':
        return Colors.orangeAccent;
      case 'user':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'all':
        return Icons.campaign;
      case 'course':
        return Icons.school;
      case 'user':
        return Icons.person;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'all':
        return 'الجميع';
      case 'course':
        return 'دورة';
      case 'user':
        return 'مستخدم';
      default:
        return type ?? '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
