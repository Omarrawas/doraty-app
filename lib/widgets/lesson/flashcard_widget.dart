import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/flashcard.dart';

class FlashcardWidget extends StatefulWidget {
  final List<Flashcard> flashcards;
  final String title;

  const FlashcardWidget({
    super.key,
    required this.flashcards,
    required this.title,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  int _currentCardIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextCard() {
    if (_currentCardIndex < widget.flashcards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.style_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'البطاقة ${_currentCardIndex + 1} من ${widget.flashcards.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اضغط على البطاقة لقلبها',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCardIndex = index;
                    });
                  },
                  itemCount: widget.flashcards.length,
                  itemBuilder: (context, index) {
                    return _buildFlipCard(widget.flashcards[index]);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentCardIndex > 0 ? _previousCard : null,
                    icon: const Icon(Icons.arrow_forward),
                    color: Colors.white,
                    disabledColor: Colors.white.withOpacity(0.3),
                    iconSize: 32,
                  ),
                  Row(
                    children: List.generate(
                      widget.flashcards.length > 5
                          ? 5
                          : widget.flashcards.length,
                      (index) {
                        final actualIndex = widget.flashcards.length > 5
                            ? (_currentCardIndex ~/ 5) * 5 + index
                            : index;

                        if (actualIndex >= widget.flashcards.length) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentCardIndex == actualIndex
                                ? AppColors.primaryPurple
                                : Colors.white.withOpacity(0.3),
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _currentCardIndex < widget.flashcards.length - 1
                        ? _nextCard
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    disabledColor: Colors.white.withOpacity(0.3),
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlipCard(Flashcard flashcard) {
    return FlipCard(
      direction: FlipDirection.HORIZONTAL,
      front: _buildCardSide(
        content: flashcard.front,
        isfront: true,
        imageUrl: flashcard.imageUrl,
      ),
      back: _buildCardSide(
        content: flashcard.back,
        isfront: false,
      ),
    );
  }

  Widget _buildCardSide({
    required String content,
    required bool isfront,
    String? imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isfront
              ? [
                  AppColors.primaryPurple.withOpacity(0.8),
                  AppColors.primaryBlue.withOpacity(0.8),
                ]
              : [
                  AppColors.primaryBlue.withOpacity(0.8),
                  AppColors.accentPink.withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isfront && imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isfront ? 'السؤال' : 'الإجابة',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Icon(
                Icons.touch_app,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
