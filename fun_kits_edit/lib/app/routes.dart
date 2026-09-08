import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/exhibitor_register_screen.dart';
import '../features/auth/role_choice_screen.dart';
import '../features/auth/visitor_register_screen.dart';
import '../features/auth/visitor_login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/exhibitor/exhibitor_profile_screen.dart';
import '../features/lucky_draw/lucky_draw_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/puzzle/puzzle_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/scan/qr_scan_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/auth/save_progress_screen.dart';
import '../features/shop/redemption_history_screen.dart';
import '../features/shop/points_history_screen.dart';
import '../features/games/my_stats_screen.dart';
import '../features/admin/super_admin_dashboard_screen.dart';
import '../features/admin/manage_rewards_screen.dart';
import '../features/admin/manage_inventory_screen.dart';
import '../features/admin/manage_redemptions_screen.dart';
import '../features/admin/manage_users_screen.dart';
import '../features/admin/manage_booths_screen.dart';
import '../features/exhibitor/exhibitor_dashboard_screen.dart';
import '../core/services/auth_service.dart';

class AppRoutes {
  // Staff-only (organizers/exhibitors) — not linked from the visitor flow.
  static const String login = '/login';
  // Points at ExhibitorRegisterScreen — invite-code gated, the only way an
  // exhibitor account is ever created. The old open self-registration
  // ('admin' role) this used to point to is retired.
  static const String register = '/register';

  static const String home = '/home';
  static const String exhibitor = '/exhibitor';
  static const String luckyDraw = '/lucky-draw';
  static const String quiz = '/quiz';
  static const String puzzle = '/puzzle';
  static const String leaderboard = '/leaderboard';
  static const String scan = '/scan';
  static const String shop = '/shop';
  static const String saveProgress = '/save-progress';
  static const String pointsHistory = '/points-history';
  // A visitor's own most-played-game / average-score / engagement-time
  // view (roadmap item 5's visitor half) — no args, always the signed-in
  // user's own stats. The exhibitor half (ExhibitorAnalyticsScreen) needs a
  // boothId and is pushed directly from ExhibitorDashboardScreen instead,
  // same as its other MaterialPageRoute-based cards (Booth Editor, Game
  // Settings, etc.) — no named route for it here.
  static const String myStats = '/my-stats';

  // Entry-flow screens (see AuthService.lastKnownMode / app.dart's
  // bootstrap logic). roleChoice is the very-first-launch (and manual
  // "Switch Role") screen; visitorRegister/visitorLogin are the visitor
  // counterparts to register/login above (same layout, different color —
  // see their own files) — visitorLogin is what a registered visitor
  // lands back on after logging out.
  static const String roleChoice = '/role-choice';
  static const String visitorRegister = '/visitor-register';
  static const String visitorLogin = '/visitor-login';

  // Legacy 'admin' role route constants — kept only so the retired,
  // unreferenced admin_dashboard_screen.dart/register_screen.dart (left in
  // place, not deleted — see project convention) still compile. Nothing
  // wires these into the `routes` map or app.dart's routing anymore.
  static const String adminDashboard = '/admin';
  static const String manageQuiz = '/admin/quiz';
  static const String manageLuckyDraw = '/admin/lucky-draw';
  static const String manageExhibitors = '/admin/exhibitors';

  // Redemption history is visitor-facing, reached from the Shop.
  static const String redemptionHistory = '/redemptions';

  // Exhibitor — owns exactly one booth, created only via ExhibitorRegisterScreen
  // redeeming a Super-Admin-issued invite code (see AuthService.isExhibitor).
  static const String exhibitorDashboard = '/exhibitor-dashboard';

  // Super Admin — a distinct, higher-privilege role (see
  // AuthService.isSuperAdmin). Never linked from the public UI; not
  // reachable through register().
  static const String superAdminDashboard = '/super-admin';
  static const String manageRewards = '/super-admin/rewards';
  static const String manageInventory = '/super-admin/inventory';
  static const String manageRedemptions = '/super-admin/redemptions';
  static const String manageUsers = '/super-admin/users';
  static const String manageBooths = '/super-admin/booths';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const ExhibitorRegisterScreen(),
        home: (_) => const HomeScreen(),
        exhibitor: (_) => const ExhibitorProfileScreen(),
        luckyDraw: (_) => const LuckyDrawScreen(),
        quiz: (_) => const QuizScreen(),
        puzzle: (_) => const PuzzleScreen(),
        leaderboard: (_) => const LeaderboardScreen(),
        scan: (_) => const QrScanScreen(),
        shop: (_) => const ShopScreen(),
        saveProgress: (_) => const SaveProgressScreen(),
        pointsHistory: (_) => const PointsHistoryScreen(),
        myStats: (_) => const MyStatsScreen(),
        roleChoice: (_) => const RoleChoiceScreen(),
        visitorRegister: (_) => const VisitorRegisterScreen(),
        visitorLogin: (_) => const VisitorLoginScreen(),
        redemptionHistory: (_) => const RedemptionHistoryScreen(),
        exhibitorDashboard: (_) =>
            const ExhibitorGuard(child: ExhibitorDashboardScreen()),
        superAdminDashboard: (_) =>
            const SuperAdminGuard(child: SuperAdminDashboardScreen()),
        manageRewards: (_) =>
            const SuperAdminGuard(child: ManageRewardsScreen()),
        manageInventory: (_) =>
            const SuperAdminGuard(child: ManageInventoryScreen()),
        manageRedemptions: (_) =>
            const SuperAdminGuard(child: ManageRedemptionsScreen()),
        manageUsers: (_) => const SuperAdminGuard(child: ManageUsersScreen()),
        manageBooths: (_) => const SuperAdminGuard(child: ManageBoothsScreen()),
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

/// Guards every Exhibitor-only screen client-side (convenience/UX only —
/// the real enforcement is firestore.rules, which scopes every write to
/// `exhibitors/{ownerUid==self}` regardless of what the Flutter UI shows).
class ExhibitorGuard extends StatelessWidget {
  const ExhibitorGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isExhibitor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied — exhibitors only.'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return child;
  }
}

/// Guards every Super Admin screen client-side (a convenience/UX guard —
/// the REAL enforcement is Firestore Security Rules, since a guard here
/// only stops the Flutter UI from rendering the screen, not a client that
/// talks to Firestore directly). Reject-first: nobody reaches the child
/// widget unless AuthService already confirms `isSuperAdmin`.
class SuperAdminGuard extends StatelessWidget {
  const SuperAdminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isSuperAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied — Super Admins only.'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return child;
  }
}
