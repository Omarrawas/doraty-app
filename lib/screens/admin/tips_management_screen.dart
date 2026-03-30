import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import 'package:go_router/go_router.dart';

class TipsManagementScreen extends StatefulWidget {
  const TipsManagementScreen({super.key});

  @override
  State<TipsManagementScreen> createState() => _TipsManagementScreenState();
}

class _TipsManagementScreenState extends State<TipsManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Tip> _tips = [];
  bool _isLoading = true;

  String _t(String key) {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTips(forceRefresh: true);
      setState(() {
        _tips = data.map((e) => Tip.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('error_loading')}: $e')),
        );
      }
    }
  }

  Future<void> _deleteTip(Tip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_tip')),
        content: Text(_t('delete_tip_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteTip(tip.id);
        _loadTips();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('tip_deleted_success'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_t('error_delete_tip')}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_t('tips_management')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTips,
          ),
        ],
      ),
      body: DynamicGradientBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _tips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 80, color: AppColors.getTextColor(context).withOpacity(0.24)),
                        SizedBox(height: 16),
                        Text(
                          _t('no_tips_found'),
                          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 18),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToCreate(),
                          icon: Icon(Icons.add),
                          label: Text(_t('add_first_tip')),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 120, 16, 100),
                    itemCount: _tips.length,
                    itemBuilder: (context, index) {
                      final tip = _tips[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        color: AppColors.getCardColor(context),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.getBorderColor(context).withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(12),
                          leading: Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: tip.thumbnailUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(tip.thumbnailUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Colors.black26,
                            ),
                            child: tip.thumbnailUrl == null
                                ? Icon(Icons.video_library, color: AppColors.getTextColor(context).withOpacity(0.24))
                                : null,
                          ),
                          title: Text(
                            tip.title,
                            style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.visibility, size: 14, color: AppColors.getTextColor(context).withOpacity(0.54)),
                                  SizedBox(width: 4),
                                  Text('${tip.viewsCount} ${_t('views_unit')}', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 12)),
                                ],
                              ),
                              if (tip.linkedCourse != null) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.link, size: 14, color: AppColors.of(context).primary),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${_t('linked_to_course')}: ${tip.linkedCourse!.title}',
                                          style: TextStyle(color: AppColors.of(context).primary, fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blueAccent),
                                onPressed: () => _navigateToCreate(tip: tip),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteTip(tip),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(),
        backgroundColor: AppColors.primaryPurple,
        icon: Icon(Icons.add),
        label: Text(_t('new_tip')),
      ),
    );
  }

  void _navigateToCreate({Tip? tip}) async {
    final path =
        tip != null ? '/admin/tips/edit/${tip.id}' : '/admin/tips/create';
    final result = await context.push(path, extra: tip);

    if (result == true) {
      _loadTips();
    }
  }
}
