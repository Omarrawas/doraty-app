import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  /// Check and update user streak based on activity
  Future<void> updateStreak() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      final userData = await SupabaseService.instance.client
          .from('users')
          .select('streak_count, last_activity_date, badges')
          .eq('id', userId)
          .single();

      final currentStreak = userData['streak_count'] as int? ?? 0;
      final lastActivityStr = userData['last_activity_date'] as String?;
      final badges = List<String>.from(userData['badges'] ?? []);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastActivityStr == null) {
        // First activity ever
        await _saveStreak(userId, 1, now, badges);
        return;
      }

      final lastActivity = DateTime.parse(lastActivityStr);
      final lastActivityDay = DateTime(lastActivity.year, lastActivity.month, lastActivity.day);

      final difference = today.difference(lastActivityDay).inDays;

      if (difference == 0) {
        // Already active today, do nothing
        return;
      } else if (difference == 1) {
        // Consecutive day
        final newStreak = currentStreak + 1;
        final updatedBadges = _checkNewBadges(newStreak, badges);
        await _saveStreak(userId, newStreak, now, updatedBadges);
      } else {
        // Streak broken
        await _saveStreak(userId, 1, now, badges);
      }
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }
  }

  Future<void> _saveStreak(String userId, int count, DateTime lastDate, List<String> badges) async {
    await SupabaseService.instance.client.from('users').update({
      'streak_count': count,
      'last_activity_date': lastDate.toIso8601String(),
      'badges': badges,
    }).eq('id', userId);
  }

  List<String> _checkNewBadges(int streak, List<String> currentBadges) {
    final newBadges = List<String>.from(currentBadges);
    
    final streakMilestones = {
      3: 'streak_3_days',
      7: 'streak_7_days',
      30: 'streak_30_days',
    };

    streakMilestones.forEach((milestone, badgeId) {
      if (streak >= milestone && !newBadges.contains(badgeId)) {
        newBadges.add(badgeId);
      }
    });

    return newBadges;
  }
}
