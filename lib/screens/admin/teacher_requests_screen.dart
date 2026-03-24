import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherRequestsScreen extends StatefulWidget {
  const TeacherRequestsScreen({super.key});

  @override
  State<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

class _TeacherRequestsScreenState extends State<TeacherRequestsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getPendingTeacherRequests();
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleStatusUpdate(String userId, String status) async {
    try {
      await _db.updateTeacherStatus(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'تمت الموافقة على المدرس' : 'تم الرفض'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                      : _requests.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد طلبات انضمام حالياً',
                                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final request = _requests[index];
                                return _buildRequestCard(request);
                              },
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'طلبات انضمام المدرسين',
              style: TextStyle(fontSize: 22, color: AppColors.getTextColor(context)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
            onPressed: _loadRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String fullName = request['full_name'] ?? 'مستخدم غير معروف';
    final String email = request['email'] ?? '';
    final String specialization = request['specialization'] ?? 'غير محدد';
    final String country = request['country'] ?? '';
    final String bio = request['bio'] ?? '';
    final String? cvUrl = request['cv_url'];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryPurple,
                  child: Text(fullName.isNotEmpty ? fullName[0] : 'U', style: TextStyle(color: AppColors.getTextColor(context))),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(email, style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 30, color: AppColors.getTextColor(context).withOpacity(0.10)),
            _buildInfoRow(Icons.workspace_premium_outlined, 'التخصص:', specialization),
            _buildInfoRow(Icons.public_rounded, 'البلد:', country),
            if (bio.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('نبذة:', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
              Text(bio, style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 14)),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                if (cvUrl != null && cvUrl.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(cvUrl)),
                      icon: Icon(Icons.description, size: 18),
                      label: Text('عرض الـ CV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                if (cvUrl != null && cvUrl.isNotEmpty) SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleStatusUpdate(request['id'], 'approved'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text('قبول'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleStatusUpdate(request['id'], 'rejected'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 16),
          SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13)),
          SizedBox(width: 4),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 13))),
        ],
      ),
    );
  }
}
