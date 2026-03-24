import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'dart:ui';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _db.getUserStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator())
                  : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.getTextColor(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 10),
          Text(
            'تحليلات التعلم',
            style: TextStyle(color: AppColors.getTextColor(context), fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryCards(),
          SizedBox(height: 30),
          _buildHeatmapPlaceholder(),
          SizedBox(height: 30),
          _buildProgressEstimator(),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            icon: Icons.timer,
            value: (_stats['learning_hours'] as double).toStringAsFixed(1),
            label: 'ساعة دراسة',
            color: Colors.blueAccent,
          ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: _buildGlassCard(
            icon: Icons.trending_up,
            value: '${(_stats['average_score'] as double).toStringAsFixed(0)}%',
            label: 'متوسط الأداء',
            color: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required IconData icon, required String value, required String label, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              SizedBox(height: 10),
              Text(value, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapPlaceholder() {
    return _buildSectionContainer(
      title: 'نشاطك اليومي',
      child: Column(
        children: [
          SizedBox(height: 10),
          // Here we would use flutter_heatmap_calendar, using a placeholder for now
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) => Container(
              margin: EdgeInsets.all(4),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: i > 4 ? AppColors.primaryPurple.withOpacity(0.8) : Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          SizedBox(height: 10),
          Text('آخر 7 أيام من النشاط التعليمي', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.38), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgressEstimator() {
    return _buildSectionContainer(
      title: 'توقعات الإكمال',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بناءً على سرعتك الحالية:', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70))),
              Text('3 كورسات قادمة', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),
          LinearProgressIndicator(
            value: 0.65,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
          ),
          SizedBox(height: 15),
          Text(
            'من المتوقع إنهاء الكورسات المسجل بها خلال 12 يوماً إذا استمررت بمعدل ساعة يومياً.',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
