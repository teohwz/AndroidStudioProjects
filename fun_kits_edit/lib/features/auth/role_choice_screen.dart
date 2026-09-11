import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../core/services/auth_service.dart';
import 'login_screen.dart';
import 'visitor_register_screen.dart';

/// The very first screen a brand-new device ever sees (see app.dart's
/// bootstrap logic, which shows this only when there's no current Firebase
/// session AND no persisted "last login mode" from a previous logout) —
/// reached that way with [hideRole] left null, showing both cards.
/// Also reachable any time afterward via "Switch Role" in Home's menu (a
/// visitor) or the Exhibitor Dashboard's menu (an exhibitor) — those two
/// callers pass [hideRole] so this screen only ever offers the *other*
/// role, never the one already signed in. Nothing here is destructive for
/// a visitor switching to Exhibitor (that just opens the existing sign-in
/// form); an exhibitor switching to Visitor is different — see
/// [_continueAsVisitor], which confirms and logs them out first.
class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key, this.hideRole});

  /// 'visitor' hides the "I am a Visitor" card (used when a visitor is the
  /// one switching — they can only switch TO Exhibitor); 'exhibitor' hides
  /// the "I am an Exhibitor" card (used when an exhibitor is switching —
  /// only TO Visitor). Null (the bootstrap/pre-login case) shows both.
  final String? hideRole;

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  bool _busy = false;

  Future<void> _continueAsVisitor() async {
    final auth = context.read<AuthService>();
    // Captured BEFORE ensureVisitorSession()/logout() below can change it —
    // this is the true "does any account (anonymous or real) already
    // exist" signal for whether "Skip — Continue as Guest" should show on
    // the next screen. Deliberately not based on Navigator.canPop(): that
    // reflects navigation-stack shape, not account state, and could stay
    // true even after this same visitor already has an anonymous account
    // (e.g. if they'd been sent back to this screen after establishing
    // one), which showed Skip again when it shouldn't have.
    final hadNoAccountYet = auth.currentUser == null;
    // An exhibitor (or Super Admin) reaching this card is switching AWAY
    // from a signed-in staff account, not just establishing a first
    // session — confirm before logging them out, since ensureVisitorSession
    // below is a no-op while any account is still signed in.
    if (auth.isExhibitor || auth.isSuperAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch to Visitor?'),
          content: const Text(
              "You'll be logged out of your exhibitor account to continue "
              'as a visitor.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Log Out & Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
      setState(() => _busy = true);
      await auth.logout();
      if (!mounted) return;
    } else {
      setState(() => _busy = true);
    }
    // Visitors never see a login wall — this silently establishes the
    // anonymous session before the register/skip screen appears, so its
    // "Skip — Continue as Guest" button has something to proceed with
    // immediately. (A no-op if some account is already signed in — which
    // after the exhibitor branch above, it no longer is.)
    await auth.ensureVisitorSession();
    if (!mounted) return;
    setState(() => _busy = false);
    // If this failed (e.g. no network), app.dart's own Consumer already
    // swaps to the "Couldn't connect" retry screen — nothing more to do here.
    if (auth.authFailed) return;
    // A brand-new visitor sees the Register screen, not the later
    // "Save My Points" prompt (that one's reserved for someone who
    // already has points at stake and wants to rank/redeem) — see
    // VisitorRegisterScreen's doc comment. Its "Skip — Continue as Guest"
    // button only makes sense the first time someone ever uses the app —
    // once an anonymous or real account already exists, hadNoAccountYet is
    // false and Skip stays hidden.
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisitorRegisterScreen(showSkip: hadNoAccountYet)));
  }

  void _continueAsExhibitor() {
    // Hide LoginScreen's "Not exhibitors? Change role" link specifically
    // when this RoleChoiceScreen instance was reached via a visitor's
    // "Switch Role" (hideRole == 'visitor') — that switch was itself the
    // deliberate way in, so no extra way back out is needed. Left visible
    // everywhere else, including true first launch (hideRole == null).
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            LoginScreen(hideChangeRole: widget.hideRole == 'visitor')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final canPop = Navigator.of(context).canPop();
    final showExhibitorCard = widget.hideRole != 'exhibitor';
    final showVisitorCard = widget.hideRole != 'visitor';
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: canPop
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.close, color: palette.textDark),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: palette.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.celebration_rounded,
                      size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Fun Kits', style: theme.textTheme.displayMedium),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text("Who's joining today?",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: palette.textMedium)),
              ),
              const SizedBox(height: 40),
              if (showExhibitorCard)
                _RoleCard(
                  icon: Icons.store_rounded,
                  title: 'I am an Exhibitor',
                  subtitle: 'Sign in to manage your booth',
                  gradient: palette.primaryGradient,
                  onTap: _busy ? null : _continueAsExhibitor,
                ),
              if (showExhibitorCard && showVisitorCard)
                const SizedBox(height: 16),
              if (showVisitorCard)
                _RoleCard(
                  icon: Icons.confirmation_number_rounded,
                  title: 'I am a Visitor',
                  subtitle: 'Play games, earn points, and win prizes',
                  gradient: palette.secondaryGradient,
                  isLoading: _busy,
                  onTap: _busy ? null : _continueAsVisitor,
                ),
              const Spacer(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: gradient.colors.first.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
