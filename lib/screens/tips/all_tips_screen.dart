import 'package:flutter/material.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../widgets/vertical_tip_player.dart';
import '../../core/theme/app_colors.dart';

class AllTipsScreen extends StatefulWidget {
  final bool showAppBar;
  const AllTipsScreen({super.key, this.showAppBar = true});

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
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTips();
      if (mounted) {
        setState(() {
          _tips = data.map((e) => Tip.fromJson(e)).toList();
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
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('نصائح دوراتي'), // More branded title
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ) : null,
      extendBodyBehindAppBar: true,
      body: DynamicGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _tips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.white24, size: 80),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد نصائح متوفرة حالياً',
                            style: TextStyle(color: Colors.white54, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                        itemCount: _tips.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          return _buildTipCard(_tips[index], index);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildTipCard(Tip tip, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerticalTipPlayer(
              tips: _tips,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: tip.thumbnailUrl != null
              ? DecorationImage(
                  image: NetworkImage(tip.thumbnailUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          color: Colors.white10,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 50,
                ),
              ),
              
              // View Count Badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${tip.viewsCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Title & Info
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tip.linkedCourse != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.link, color: AppColors.secondaryGold, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tip.linkedCourse!.title,
                              style: const TextStyle(
                                color: AppColors.secondaryGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
