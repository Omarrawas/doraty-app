import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Map<String, dynamic>>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _db.getLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _leaderboardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text(
                              ErrorUtils.getFriendlyErrorMessage(
                                  snapshot.error!),
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'Cairo')));
                    }

                    final data = snapshot.data ?? [];
                    if (data.isEmpty) {
                      return const Center(
                          child: Text('لا يوجد بيانات بعد',
                              style: TextStyle(
                                  color: Colors.white, fontFamily: 'Cairo')));
                    }

                    return _buildLeaderboardContent(data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'لوحة المتصدرين',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent(List<Map<String, dynamic>> data) {
    final topThree = data.take(3).toList();
    final theRest = data.skip(3).toList();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _leaderboardFuture = _db.getLeaderboard();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTopThree(topThree),
            const SizedBox(height: 30),
            _buildList(theRest),
          ],
        ),
      ),
    );
  }

  Widget _buildTopThree(List<Map<String, dynamic>> topThree) {
    if (topThree.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (topThree.length >= 2) _buildTopUser(topThree[1], 2, 100),
          const SizedBox(width: 15),
          // 1st Place
          _buildTopUser(topThree[0], 1, 140),
          const SizedBox(width: 15),
          // 3rd Place
          if (topThree.length >= 3) _buildTopUser(topThree[2], 3, 90),
        ],
      ),
    );
  }

  Widget _buildTopUser(Map<String, dynamic> user, int rank, double height) {
    Color rankColor;
    double iconSize;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      iconSize = 30;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      iconSize = 25;
    } else {
      rankColor = const Color(0xFFCD7F32); // Bronze
      iconSize = 20;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                width: rank == 1 ? 90 : 75,
                height: rank == 1 ? 90 : 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user['avatar_url'] != null
                      ? Image.network(user['avatar_url'], fit: BoxFit.cover)
                      : Container(
                          color: Colors.white.withOpacity(0.1),
                          child: const Icon(Icons.person,
                              color: Colors.white30, size: 40),
                        ),
                ),
              ),
            ),
            Icon(Icons.emoji_events, color: rankColor, size: iconSize),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          user['full_name'] ?? 'طالب',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          '${user['points']} نقطة',
          style: TextStyle(
            color: rankColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            user['rank_title'],
            style:
                TextStyle(color: rankColor, fontSize: 10, fontFamily: 'Cairo'),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(users.length, (index) {
          final user = users[index];
          final rank = index + 4;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 15),
                  CircleAvatar(
                    backgroundImage: user['avatar_url'] != null
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    backgroundColor: Colors.white10,
                    child: user['avatar_url'] == null
                        ? const Icon(Icons.person,
                            size: 20, color: Colors.white38)
                        : null,
                  ),
                ],
              ),
              title: Text(
                user['full_name'] ?? 'طالب',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                user['rank_title'],
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontFamily: 'Cairo'),
              ),
              trailing: Text(
                '${user['points']} نقطة',
                style: const TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
