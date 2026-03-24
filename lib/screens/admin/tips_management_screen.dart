import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'create_tip_screen.dart';

class TipsManagementScreen extends StatefulWidget {
  TipsManagementScreen({super.key});

  @override
  State<TipsManagementScreen> createState() => _TipsManagementScreenState();
}

class _TipsManagementScreenState extends State<TipsManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Tip> _tips = [];
  bool _isLoading = true;

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
          SnackBar(content: Text('خطأ في تحميل النصائح: $e')),
        );
      }
    }
  }

  Future<void> _deleteTip(Tip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف النصيحة'),
        content: Text('هل أنت متأكد من حذف "${tip.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حذف'),
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
            SnackBar(content: Text('تم حذف النصيحة بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الحذف: $e')),
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
        title: Text('إدارة النصائح'),
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
                          'لا توجد نصائح حالياً',
                          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 18),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToCreate(),
                          icon: Icon(Icons.add),
                          label: Text('أضف أول نصيحة'),
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
                        color: AppColors.getMutedTextColor(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                                  Text('${tip.viewsCount} مشاهدة', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 12)),
                                ],
                              ),
                              if (tip.linkedCourse != null) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.link, size: 14, color: AppColors.secondaryGold),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'مرتبط بدورة: ${tip.linkedCourse!.title}',
                                        style: TextStyle(color: AppColors.secondaryGold, fontSize: 12),
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
        label: Text('نصيحة جديدة'),
      ),
    );
  }

  void _navigateToCreate({Tip? tip}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTipScreen(tip: tip),
      ),
    );

    if (result == true) {
      _loadTips();
    }
  }
}
