import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../widgets/vertical_tip_player.dart';

/// Discovery-style screen for Tips (TikTok-like vertical feed)
class AllTipsScreen extends StatefulWidget {
  final bool showAppBar;
  final bool isVisible;
  final bool showCloseButton;
  AllTipsScreen({
    super.key, 
    this.showAppBar = false,
    this.isVisible = true,
    this.showCloseButton = true,
  });

  @override
  State<AllTipsScreen> createState() => _AllTipsScreenState();
}

class _AllTipsScreenState extends State<AllTipsScreen> with AutomaticKeepAliveClientMixin {
  final DatabaseService _db = DatabaseService();
  List<Tip> _tips = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;


  List<Map<String, dynamic>> _normalizeMapList(dynamic raw) {
    if (raw is! Iterable) return <Map<String, dynamic>>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(item.map((key, value) => MapEntry(key.toString(), value)));
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTips();
      if (mounted) {
        final normalized = _normalizeMapList(data);
        
        final List<Tip> loadedTips = [];
        for (final e in normalized) {
          try {
            final tip = Tip.fromJson(e);
            // Validation: Ensure tip has a video and title
            if (tip.videoUrl.isNotEmpty) {
              loadedTips.add(tip);
            }
          } catch (err) {
            debugPrint('❌ Tip parse error: $err');
            debugPrint('Data: $e');
          }
        }

        // Sort newest to oldest
        if (loadedTips.isNotEmpty) {
          loadedTips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        
        setState(() {
          _tips = loadedTips;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading tips: $e');
        debugPrint(stack.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context))),
      );
    }

    if (_tips.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.getTextColor(context).withOpacity(0.24), size: 80),
              SizedBox(height: 16),
              Text(
                'لا توجد نصائح متوفرة حالياً',
                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Directly return the TikTok-style vertical player
    return VerticalTipPlayer(
      tips: _tips,
      initialIndex: 0,
      isVisible: widget.isVisible,
      showCloseButton: widget.showCloseButton,
    );
  }
}
