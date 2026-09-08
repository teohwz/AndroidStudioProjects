import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/exhibitor/exhibitor_profile_screen.dart';
import '../features/lucky_draw/lucky_draw_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/puzzle/puzzle_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/manage_quiz_screen.dart';
import '../features/admin/manage_lucky_draw_screen.dart';
import '../features/admin/manage_exhibitors_screen.dart';
import '../core/services/auth_service.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String exhibitor = '/exhibitor';
  static const String luckyDraw = '/lucky-draw';
  static const String quiz = '/quiz';
  static const String puzzle = '/puzzle';
  static const String leaderboard = '/leaderboard';
  static const String adminDashboard = '/admin';
  static const String manageQuiz = '/admin/quiz';
  static const String manageLuckyDraw = '/admin/lucky-draw';
  static const String manageExhibitors = '/admin/exhibitors';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const HomeScreen(),
        exhibitor: (_) => const ExhibitorProfileScreen(),
        luckyDraw: (_) => const LuckyDrawScreen(),
        quiz: (_) => const QuizScreen(),
        puzzle: (_) => const PuzzleScreen(),
        leaderboard: (_) => const LeaderboardScreen(),
        adminDashboard: (_) => const AdminGuard(child: AdminDashboardScreen()),
        manageQuiz: (_) => const AdminGuard(child: ManageQuizScreen()),
        manageLuckyDraw: (_) =>
            const AdminGuard(child: ManageLuckyDrawScreen()),
        manageExhibitors: (_) =>
            const AdminGuard(child: ManageExhibitorsScreen()),
      };
}

/// Guards a route — if the current user is not an admin, pops back and shows
/// a snackbar. This prevents any logged-in user from navigating to admin
/// screens by typing a route name programmatically.
class AdminGuard extends StatelessWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied — admins only.'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return child;
  }
}
