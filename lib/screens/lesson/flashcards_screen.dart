import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/flashcard.dart';
import '../../models/lesson.dart';
import '../../widgets/lesson/flashcard_widget.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/dynamic_gradient_background.dart';

class FlashcardsScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Flashcard> initialCards;

  const FlashcardsScreen({
    super.key,
    required this.lesson,
    required this.initialCards,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late List<Flashcard> _cards;
  int _currentIndex = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.initialCards);
  }

  void _rateCard(int quality) async {
    final card = _cards[_currentIndex];
    
    // Simple Spaced Repetition Logic (SM-2 simplified)
    double newEase = card.easeFactor;
    int newInterval = card.interval;
    int newRep = card.repetitionCount;

    if (quality >= 3) {
      if (newRep == 0) {
        newInterval = 1;
      } else if (newRep == 1) {
        newInterval = 6;
      } else {
        newInterval = (newInterval * newEase).round();
      }
      newRep++;
      newEase = newEase + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    } else {
      newRep = 0;
      newInterval = 1;
      newEase = (newEase - 0.2).clamp(1.3, 2.5);
    }

    final updatedCard = card.copyWith(
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      interval: newInterval,
      easeFactor: newEase,
      repetitionCount: newRep,
    );

    // Update in Supabase
    if (updatedCard.id.isNotEmpty) {
      await SupabaseService.instance.client
          .from('flashcards')
          .update(updatedCard.toJson())
          .eq('id', updatedCard.id);
    }

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _isFinished = true;
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
                child: _isFinished ? _buildFinishedUI() : _buildStudyUI(),
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
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مراجعة البطاقات',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.lesson.title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FlashcardWidget(
            flashcards: [_cards[_currentIndex]],
            title: 'بطاقة ${_currentIndex + 1} من ${_cards.length}',
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'كيف كان تذكرك لهذه المعلومة؟',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRateButton('صعب', Colors.red, 1),
            const SizedBox(width: 15),
            _buildRateButton('جيد', Colors.blue, 3),
            const SizedBox(width: 15),
            _buildRateButton('سهل', Colors.green, 5),
          ],
        ),
      ],
    );
  }

  Widget _buildRateButton(String label, Color color, int quality) {
    return ElevatedButton(
      onPressed: () => _rateCard(quality),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildFinishedUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text(
            'أحسنت! أنهيت مراجعة اليوم',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'لقد تم تحديث مواعيد المراجعة القادمة آلياً.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('العودة للدرس', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
