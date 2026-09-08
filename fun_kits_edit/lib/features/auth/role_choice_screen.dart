import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'login_screen.dart';
import 'visitor_register_screen.dart';

/// The very first screen a brand-new device ever sees (see app.dart's
/// bootstrap logic, which shows this only when there's no current Firebase
/// session AND no persisted "last login mode" from a previous logout).
/// Also reachable any time afterward via "Switch Role" in Home's menu —
/// nothing here is destructive: picking "Exhibitor" just opens the existing
/// sign-in form, and picking "Visitor" only ensures an anonymous session
/// exists (creating one silently if this is truly the first time) before
/// handing off to the register/skip screen.
class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  bool _busy = false;

  Future<void> _continueAsVisitor() async {
    final auth = context.read<AuthService>();
    setState(() => _busy = true);
    // Visitors never see a login wall — this silently establishes the
    // anonymous session before the register/skip screen appears, so its
    // "Skip — Continue as Guest" button has something to proceed with
    // immediately.
    await auth.ensureVisitorSession();
    if (!mounted) return;
    setState(() => _busy = false);
    // If this failed (e.g. no network), app.dart's own Consumer already
    // swaps to the "Couldn't connect" retry screen — nothing more to do here.
    if (auth.authFailed) return;
    // A brand-new visitor sees the Register screen, not the later
    // "Save My Points" prompt (that one's reserved for someone who
    // already has points at stake and wants to rank/redeem) — see
    // VisitorRegisterScreen's doc comment.
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VisitorRegisterScreen()));
  }

  void _continueAsExhibitor() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
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
                          icon: const Icon(Icons.close,
                              color: AppColors.textDark),
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
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.celebration,
                      size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('Fun Kits',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text("Who's joining today?",
                    style:
                        TextStyle(fontSize: 15, color: AppColors.textMedium)),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                emoji: '🏢',
                title: 'I am an Exhibitor',
                subtitle: 'Sign in to manage your booth',
                gradient: AppColors.primaryGradient,
                onTap: _busy ? null : _continueAsExhibitor,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                emoji: '🎟️',
                title: 'I am a Visitor',
                subtitle: 'Play games, earn points, and win prizes',
                gradient: AppColors.secondaryGradient,
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
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.isLoading = false,
  });

  final String emoji;
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
              Text(emoji, style: const TextStyle(fontSize: 34)),
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
