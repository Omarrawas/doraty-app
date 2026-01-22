import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/course.dart';

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
      // 1. Record in Database
      await SupabaseService.instance.client.from('admin_notifications').insert({
        'title': _title,
        'body': _body,
        'notification_type': _targetType,
        'target_id': _selectedTargetId,
        'sender_id': SupabaseService.instance.currentUserId,
      });

      // 2. Trigger Sending Logic (Placeholder / Edge Function Call)
      // Since we don't have the Edge Function setup with keys yet,
      // we will simulate the success and inform the user.
      // Ideally: await supabase.functions.invoke('send-push', body: { ... });
      
      // Sending logic via NotificationService helper (if we implemented it to call sending API)
      // specific logic would go here. For now, we assume the DB record is enough 
      // or that an external trigger watches the table.
      
      // TODO: Implement actual FCM sending call here using Edge Function
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الإشعار بنجاح (تسجيل في قاعدة البيانات)'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _targetType = 'all';
          _selectedTargetId = null;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإشعارات'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compose Section
            _buildComposeSection(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            // History Section
            const Text(
              'سجل الإشعارات المرسلة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إرسال إشعار جديد',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Target Type Dropdown
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(
                  labelText: 'إرسال إلى',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع المستخدمين')),
                  DropdownMenuItem(value: 'course', child: Text('طلاب دورة محددة')),
                  DropdownMenuItem(value: 'user', child: Text('مستخدم محدد')),
                ],
                onChanged: (val) {
                  setState(() {
                    _targetType = val!;
                    _selectedTargetId = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Conditional Selection Fields
              if (_targetType == 'course')
                DropdownButtonFormField<String>(
                  value: _selectedTargetId,
                  decoration: const InputDecoration(
                    labelText: 'اختر الدورة',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _courses.map((course) {
                    return DropdownMenuItem(
                      value: course.id,
                      child: Text(
                        course.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTargetId = val),
                  validator: (val) =>
                      val == null ? 'يرجى اختيار الدورة' : null,
                ),

              if (_targetType == 'user')
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'بحث عن مستخدم (الاسم أو البريد)',
                        suffixIcon: _isLoadingData
                            ? Transform.scale(
                                scale: 0.5, child: const CircularProgressIndicator())
                            : const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        // Debounce logic could be added here
                        if (val.length > 2) _searchUsers(val);
                      },
                    ),
                    if (_users.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
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
                              title: Text(user['full_name'] ?? 'بدون اسم'),
                              subtitle: Text(user['email'] ?? ''),
                              selected: isSelected,
                              selectedTileColor:
                                  AppColors.primaryPurple.withOpacity(0.1),
                              onTap: () {
                                setState(() {
                                  _selectedTargetId = user['id'];
                                  _users = []; // Clear list after selection
                                });
                              },
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: AppColors.primaryPurple)
                                  : null,
                            );
                          },
                        ),
                      ),
                    if (_selectedTargetId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'المستخدم المختار: $_selectedTargetId',
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 12),
              // Title
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'مطلوب' : null,
                onSaved: (val) => _title = val!,
                onChanged: (val) => _title = val,
              ),
              const SizedBox(height: 12),
              // Body
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'نص الإشعار',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (val) =>
                    val == null || val.isEmpty ? 'مطلوب' : null,
                onSaved: (val) => _body = val!,
                onChanged: (val) => _body = val,
              ),
              const SizedBox(height: 20),
              // Send Button
              ElevatedButton(
                onPressed: _isSending ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send),
                          SizedBox(width: 8),
                          Text('إرسال الإشعار',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const Center(child: Text('لا يوجد سجل للإشعارات'));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTypeColor(item['notification_type']),
              child: Icon(_getTypeIcon(item['notification_type']),
                  color: Colors.white, size: 20),
            ),
            title: Text(item['title'] ?? ''),
            subtitle: Text(
                '${item['body']}\n${_formatDate(item['created_at'])}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: Chip(
              label: Text(_getTypeLabel(item['notification_type']),
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: _getTypeColor(item['notification_type']),
              padding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'all':
        return Colors.blue;
      case 'course':
        return Colors.orange;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'all':
        return Icons.campaign;
      case 'course':
        return Icons.class_;
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
      return '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}';
    } catch (e) {
      return dateStr;
    }
  }
}
