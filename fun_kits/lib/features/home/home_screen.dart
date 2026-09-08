import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../app/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 52, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Welcome to 🎪',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Text('Fun Kits',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    // Real-time points display
                    if (uid != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('leaderboard')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snap) {
                          final points = snap.data?.data() != null
                              ? (snap.data!.data()
                                      as Map<String, dynamic>)['totalPoints'] ??
                                  0
                              : 0;
                          return Text('My Points: $points pts',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700));
                        },
                      )
                    else
                      const Text('Pick your game and start earning points!',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 20)),
                onSelected: (v) async {
                  if (v == 'logout') {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
              ),
            ],
          ),

          // ── Feature Grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.casino_rounded,
                  title: 'Lucky Draw',
                  subtitle: 'Try your luck!',
                  color: AppColors.luckyDrawColor,
                  route: AppRoutes.luckyDraw,
                  emoji: '🎰',
                ),
                _FeatureCard(
                  icon: Icons.quiz_rounded,
                  title: 'Quiz',
                  subtitle: 'Test your knowledge',
                  color: AppColors.quizColor,
                  route: AppRoutes.quiz,
                  emoji: '🧠',
                ),
                _FeatureCard(
                  icon: Icons.extension_rounded,
                  title: 'Puzzle',
                  subtitle: 'Solve & win points',
                  color: AppColors.puzzleColor,
                  route: AppRoutes.puzzle,
                  emoji: '🧩',
                ),
                _FeatureCard(
                  icon: Icons.leaderboard_rounded,
                  title: 'Leaderboard',
                  subtitle: 'Top players',
                  color: AppColors.leaderboardColor,
                  route: AppRoutes.leaderboard,
                  emoji: '🏆',
                ),
                _FeatureCard(
                  icon: Icons.store_rounded,
                  title: 'Exhibitors',
                  subtitle: 'Explore booths',
                  color: AppColors.exhibitorColor,
                  route: AppRoutes.exhibitor,
                  emoji: '🏢',
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    required this.emoji,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
