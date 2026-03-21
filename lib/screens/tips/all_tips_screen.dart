import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../widgets/vertical_tip_player.dart';

/// Discovery-style screen for Tips (TikTok-like vertical feed)
class AllTipsScreen extends StatefulWidget {
  final bool showAppBar;
  const AllTipsScreen({super.key, this.showAppBar = false});

  @override
  State<AllTipsScreen> createState() => _AllTipsScreenState();
}

class _AllTipsScreenState extends State<AllTipsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Tip> _tips = [];
  bool _isLoading = true;

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
        final List<Tip> loadedTips = data.map((e) => Tip.fromJson(e)).toList();
        // Shuffle for randomness (TikTok style)
        loadedTips.shuffle();
        
        setState(() {
          _tips = loadedTips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading tips: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_tips.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.white24, size: 80),
              SizedBox(height: 16),
              Text(
                'لا توجد نصائح متوفرة حالياً',
                style: TextStyle(color: Colors.white54, fontSize: 18),
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
    );
  }
}
