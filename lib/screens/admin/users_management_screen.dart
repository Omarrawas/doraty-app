import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserRole;
  String _selectedRoleFilter = 'all'; // Added

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _db.getAllUsers();
      final roles = await _db.getRoles();
      final currentRole = await _db.getUserRole(); // Added

      setState(() {
        _users = users;
        _roles = roles;
        _currentUserRole = currentRole; // Added
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> filtered = _users;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        final name = user['full_name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        final phone = user['phone_number']?.toString().toLowerCase() ?? '';
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    }

    // Filter by role
    if (_selectedRoleFilter != 'all') {
      filtered = filtered.where((user) {
        final userRoles = user['user_roles'] as List? ?? [];
        final roleName = userRoles.isNotEmpty
            ? (userRoles.first['roles']?['name']?.toString() ?? 'student')
            : 'student';

        if (_selectedRoleFilter == 'admin') {
          return roleName == 'admin' || roleName == 'super_admin';
        }
        return roleName == _selectedRoleFilter;
      }).toList();
    }

    return filtered;
  }

  int _getRoleCount(String role) {
    if (role == 'all') return _users.length;
    if (role == 'admin') {
      return _users.where((u) {
        final roles = u['user_roles'] as List? ?? [];
        return roles.any((r) =>
            r['roles']?['name'] == 'admin' || r['roles']?['name'] == 'super_admin');
      }).length;
    }
    if (role == 'teacher') {
      return _users.where((u) {
        final roles = u['user_roles'] as List? ?? [];
        return roles.any((r) => r['roles']?['name'] == 'teacher');
      }).length;
    }
    if (role == 'student') {
      return _users.where((u) {
        final roles = u['user_roles'] as List? ?? [];
        return roles.isEmpty ||
            roles.any((r) =>
                r['roles']?['name'] == 'student' || r['roles']?['name'] == null);
      }).length;
    }
    return 0;
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
                _buildSearchBar(context),
                _buildFilterChips(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _filteredUsers.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: GridView.builder(
                                padding: EdgeInsets.all(20),
                                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  childAspectRatio: 0.72,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  return _buildUserCard(
                                      context, _filteredUsers[index]);
                                },
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
      padding: EdgeInsets.all(20),
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
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _t('admin_users'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_t('all')}: ${_users.length} | ${_t('admin_role_label')}: ${_getRoleCount('admin')}',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Text(
                  '${_t('teacher_role_label')}: ${_getRoleCount('teacher')} | ${_t('student_role_label')}: ${_getRoleCount('student')}',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: _t('search_users_hint'),
                hintStyle: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.getTextColor(context).withOpacity(0.7)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildRoleChip('all', _t('all')),
          SizedBox(width: 8),
          _buildRoleChip('admin', _t('admin_role_label')),
          SizedBox(width: 8),
          _buildRoleChip('teacher', _t('teacher_role_label')),
          SizedBox(width: 8),
          _buildRoleChip('student', _t('student_role_label')),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role, String label) {
    final isSelected = _selectedRoleFilter == role;
    final color = _getRoleColor(role);

    return FilterChip(
      selected: isSelected,
      label: Text('$label (${_getRoleCount(role)})'),
      onSelected: (selected) {
        setState(() => _selectedRoleFilter = role);
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.getTextColor(context).withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? color
              : AppColors.getGlassColor(context, opacity: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final userRoles = user['user_roles'] as List? ?? [];
    final roleName = userRoles.isNotEmpty
        ? (userRoles.first['roles']?['display_name'] ?? _t('student_role'))
        : _t('student_role');

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                      radius: 30,
                      child: Text(
                        (user['full_name']?.toString()[0] ?? 'U').toUpperCase(),
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 24,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      StringUtils.cleanTeacherName(
                          user['full_name'] ?? _t('user')),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      user['email'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextColor(context)
                            .withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    if (_canManageRole(user))
                      _buildActionButton(
                        context: context,
                        icon: Icons.admin_panel_settings,
                        label: _t('assign_role'),
                        onTap: () => _showRoleDialog(user),
                      )
                    else
                      Text(
                        _t('cannot_edit_admin_roles'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.getTextColor(context,
                              secondary: true),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(roleName).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getRoleColor(roleName).withOpacity(0.5), width: 1),
                  ),
                  child: Text(
                    roleName,
                    style: TextStyle(
                      color: _getRoleColor(roleName),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'all':
        return AppColors.primaryPurple;
      case 'مدير عام':
      case 'super_admin':
        return Colors.red;
      case 'مدير':
      case 'admin':
        return Colors.orange;
      case 'مدرس':
      case 'teacher':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  bool _canManageRole(Map<String, dynamic> targetUser) {
    if (_currentUserRole == 'super_admin') return true;

    // Admins can only manage students and teachers, not other admins
    final targetUserRoles = targetUser['user_roles'] as List? ?? [];
    if (targetUserRoles.isEmpty) return true; // Student

    final targetRole =
        targetUserRoles.first['roles']?['name']?.toString() ?? 'student';
    return targetRole == 'student' || targetRole == 'teacher';
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: AppColors.getTextColor(context), size: 18),
                    SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people,
                      color: AppColors.getTextColor(context), size: 64),
                  SizedBox(height: 16),
                  Text(
                    _t('no_results'),
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextColor(context).withOpacity(0.8),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        title: Text(_t('assign_role'), style: TextStyle(color: AppColors.getTextColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles.where((r) {
            // Admins cannot assign admin/super_admin roles
            if (_currentUserRole != 'super_admin') {
              return r['name'] != 'admin' && r['name'] != 'super_admin';
            }
            return true;
          }).map((role) {
            return ListTile(
              title: Text(
                role['display_name'] ?? '',
                style: TextStyle(color: AppColors.getTextColor(context)),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _db.assignRole(user['id'], role['name']);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(_t('role_assigned_success')),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'), style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );
  }
}
