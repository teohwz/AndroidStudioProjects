import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../features/home/home_screen.dart';
import '../features/admin/super_admin_dashboard_screen.dart';
import '../features/exhibitor/exhibitor_dashboard_screen.dart';
import '../features/auth/role_choice_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/visitor_login_screen.dart';
import 'routes.dart';

class FunKitsApp extends StatelessWidget {
  const FunKitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun Kits',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Nunito',
        useMaterial3: true,
      ),
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
            if (auth.authFailed) {
              return _AuthErrorScreen(
                message: auth.authError,
                onRetry: () => auth.retryVisitorSession(),
              );
            }
            switch (auth.lastKnownMode) {
              case 'exhibitor':
                return const LoginScreen();
              case 'visitor':
                return const VisitorLoginScreen();
              default:
                return const RoleChoiceScreen();
            }
          }
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Ban check is live (a stream, not the login-time-cached role) so
          // a Super Admin banning someone takes effect immediately, without
          // requiring the banned user to sign out first.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snap) {
              final status = snap.data?.data()?['accountStatus'] as String?;
              if (status == 'banned') {
                return _BannedScreen(onLogout: () => auth.logout());
              }
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
                'Your account has been suspended by an administrator. '
                'Contact the event organizers if you think this is a mistake.',
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
