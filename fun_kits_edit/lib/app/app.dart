import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../core/services/firestore_service.dart';
import '../core/theme/app_theme.dart';
import '../features/home/home_screen.dart';
import '../features/admin/super_admin_dashboard_screen.dart';
import '../features/exhibitor/exhibitor_dashboard_screen.dart';
import '../features/auth/role_choice_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/visitor_login_screen.dart';
import 'routes.dart';

/// Shared suspension-message wording, used both by `_BannedScreen` (the
/// passive screen still shown to a banned exhibitor/Super Admin) and by the
/// popup `_BanNoticeGate` shows a banned visitor after
/// [AuthService.forceLogoutForBan] signs them out — one literal so the two
/// banned-account messages in this file can never drift apart.
const String _kVisitorBanMessage =
    'Your account has been suspended by an administrator. Contact the '
    'event organizers if you think this is a mistake.';

class FunKitsApp extends StatelessWidget {
  const FunKitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun Kits',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routes: AppRoutes.routes,
      // Entry flow: the very first launch ever (no session, nothing
      // persisted) shows RoleChoiceScreen — "I am an Exhibitor" / "I am a
      // Visitor" — rather than silently creating an anonymous session.
      // Every launch after that is driven by whatever's actually true:
      // an existing session (anonymous or real) routes straight in below,
      // and a logged-out exhibitor/registered-visitor lands back on their
      // own login page via AuthService.lastKnownMode (set by logout()).
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          // Wait for the first authStateChanges event before deciding
          // anything, so a returning user's already-persisted session has
          // a chance to resolve and we never flash the wrong screen.
          if (!auth.authInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.currentUser == null) {
            // A failed anonymous sign-in used to leave visitors on an
            // infinite spinner with no way forward. Show what went wrong
            // and let them retry instead.
            Widget screen;
            if (auth.authFailed) {
              screen = _AuthErrorScreen(
                message: auth.authError,
                onRetry: () => auth.retryVisitorSession(),
              );
            } else {
              switch (auth.lastKnownMode) {
                case 'exhibitor':
                  screen = const LoginScreen();
                  break;
                case 'visitor':
                  screen = const VisitorLoginScreen();
                  break;
                default:
                  screen = const RoleChoiceScreen();
              }
            }
            // A banned visitor who was just force-signed-out by the ban
            // check below lands here (lastKnownMode == 'visitor') with a
            // one-time message waiting — show it once via a blocking
            // popup, then clear it so it never reappears on a later,
            // unrelated visit to this same screen.
            if (auth.pendingBanMessage != null) {
              return _BanNoticeGate(
                message: auth.pendingBanMessage!,
                onDismissed: auth.clearPendingBanMessage,
                child: screen,
              );
            }
            return screen;
          }
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Belt-and-suspenders guard alongside AuthService's own internal
          // ordering: never route to Home/a dashboard until the role for
          // THIS specific signed-in uid has been explicitly confirmed —
          // closes the gap that let the visitor Home screen flash for a
          // Super Admin on some cold starts (see the app-launch-flash
          // entries in the project doc), regardless of the exact auth
          // event interleaving that produced the stale role.
          if (!auth.isRoleReadyForCurrentUser) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Ban check is live (a stream, not the login-time-cached role) so
          // a Super Admin banning someone takes effect immediately, without
          // requiring the banned user to sign out first. Routed through
          // FirestoreService.watchUserProfile() (its stream cache, keyed by
          // uid) rather than a raw inline `.snapshots()` call — this widget
          // sits at the very root of the app and rebuilds on every single
          // AuthService.notifyListeners() call, so a raw inline stream here
          // was re-subscribing a fresh Firestore listener on every one of
          // those (isLoading toggles, role changes, auth state changes —
          // several of which fire in quick succession during register/
          // logout/switch-role), which is exactly what made that flow feel
          // laggy even after the app-wide stream-caching fix, since this
          // one spot never went through FirestoreService at all.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().watchUserProfile(auth.currentUser!.uid),
            builder: (context, snap) {
              // Don't fall through to Home/a dashboard before this stream's
              // first real snapshot arrives — its very first
              // ConnectionState.waiting build has snap.data == null, which
              // would otherwise read as "not banned" (a ban only shows up
              // once real data arrives) and briefly route past the ban
              // check on every cold start/reconnect, not just for an
              // account that's actually banned. Ban enforcement itself now
              // also has a real server-side backstop — see the isBanned()
              // rule added to game_sessions/booth_checkins/redemptions —
              // so a banned account can no longer act even if it manages
              // to see this screen for a moment.
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final status = snap.data?.data()?['accountStatus'] as String?;
              if (status == 'banned') {
                if (auth.isSuperAdmin || auth.isExhibitor) {
                  // Staff accounts keep the existing passive "Suspended"
                  // screen with a manual Sign Out button.
                  return _BannedScreen(onLogout: () => auth.logout());
                }
                // A banned VISITOR sitting at the app root (Home) is
                // force-signed-out immediately instead — no button, no
                // further chance to keep playing/scanning from here. The
                // actual popup is shown once they land on the resulting
                // login/role-choice screen (see the currentUser == null
                // branch above / AuthService.forceLogoutForBan()).
                // Scheduled for after this frame (never call
                // notifyListeners()-triggering code from inside build) and
                // guarded inside AuthService against firing more than once
                // while the async sign-out is still in flight.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  auth.forceLogoutForBan(_kVisitorBanMessage);
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              // TEMPORARY diagnostic logging — see the "app-launch flash"
              // entries in the project doc. Safe to remove once that's
              // confirmed fixed.
              debugPrint('[app.dart] routing decision: '
                  'uid=${auth.currentUser?.uid} role=${auth.role} '
                  'isSuperAdmin=${auth.isSuperAdmin} '
                  'isExhibitor=${auth.isExhibitor} at ${DateTime.now()}');
              if (auth.isSuperAdmin) return const SuperAdminDashboardScreen();
              // The old shared 'admin' role (global Quiz/Lucky Draw/
              // Exhibitor management) is retired — an 'exhibitor' now owns
              // exactly one booth instead. AdminDashboardScreen is left in
              // place, unreferenced, rather than deleted.
              return auth.isExhibitor
                  ? const ExhibitorDashboardScreen()
                  : const HomeScreen();
            },
          );
        },
      ),
    );
  }
}

/// Wraps whatever login/role-choice screen a signed-out visitor is about to
/// see with a one-time blocking popup explaining they were just force-
/// signed-out for being banned (see `AuthService.forceLogoutForBan()` /
/// `pendingBanMessage`). Shown from `initState` (via a post-frame callback,
/// since `showDialog` needs a fully laid-out `BuildContext`) rather than
/// from the ban-check `StreamBuilder` itself, so it only ever fires once
/// the visitor has actually landed on the new screen — not mid-sign-out,
/// and not once per rebuild while `logout()` is still in flight. The
/// `_shown` flag additionally guards against Flutter re-running this
/// `State`'s `initState`-scheduled callback if this widget instance is
/// ever rebuilt in place before the popup has been dismissed.
class _BanNoticeGate extends StatefulWidget {
  const _BanNoticeGate({
    required this.message,
    required this.onDismissed,
    required this.child,
  });

  final String message;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_BanNoticeGate> createState() => _BanNoticeGateState();
}

class _BanNoticeGateState extends State<_BanNoticeGate> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnce());
  }

  Future<void> _showOnce() async {
    if (_shown || !mounted) return;
    _shown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Suspended'),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown instead of the whole app when a Super Admin has banned this
/// account (`users/{uid}.accountStatus == 'banned'`). Live via a stream, so
/// it also takes effect the moment an admin unbans them (no re-login
/// needed either way).
class _BannedScreen extends StatelessWidget {
  const _BannedScreen({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚫', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Account Suspended',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                _kVisitorBanMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 20),
              TextButton(onPressed: onLogout, child: const Text('Sign Out')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when ensureVisitorSession() couldn't sign the visitor in — most
/// commonly no internet on the device/emulator, or Anonymous sign-in not
/// enabled in the Firebase Console.
class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text("Couldn't connect",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Check your internet connection and try again.'
                '${message != null ? '\n\n$message' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
