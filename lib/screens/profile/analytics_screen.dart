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
                  ? const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          const Text(
            'تحليلات التعلم',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 30),
          _buildHeatmapPlaceholder(),
          const SizedBox(height: 30),
          _buildProgressEstimator(),
          const SizedBox(height: 30),
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
        const SizedBox(width: 15),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
          const SizedBox(height: 10),
          // Here we would use flutter_heatmap_calendar, using a placeholder for now
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) => Container(
              margin: const EdgeInsets.all(4),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: i > 4 ? AppColors.primaryPurple.withOpacity(0.8) : Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          const SizedBox(height: 10),
          const Text('آخر 7 أيام من النشاط التعليمي', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgressEstimator() {
    return _buildSectionContainer(
      title: 'توقعات الإكمال',
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بناءً على سرعتك الحالية:', style: TextStyle(color: Colors.white70)),
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
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
