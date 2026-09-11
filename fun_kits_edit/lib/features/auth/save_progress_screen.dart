import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';
import 'visitor_register_screen.dart';

/// The in-context "protect what you've already earned" prompt — reached
/// only by choice, from Home's Save-Points banner, the Shop's redeem-time
/// nudge, or the Leaderboard's guest banner (never a gate: a guest can keep
/// playing anonymously forever). Has no form of its own — the single
/// Register button below hands off to [VisitorRegisterScreen], which does
/// the actual AuthService.linkEmail() work on this same anonymous account
/// (so nothing earned so far is lost) and already offers its own "Already
/// have an account? Sign in" link, so both register and sign-back-in are
/// one tap away from here either way.
class SaveProgressScreen extends StatelessWidget {
  const SaveProgressScreen({super.key});

  void _register(BuildContext context) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VisitorRegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Save My Points'),
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live points hero — the whole reason this screen exists is
              // to protect exactly this number.
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: uid == null ? null : fs.watchUserProfile(uid),
                builder: (context, snap) {
                  final points =
                      (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: palette.secondaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: palette.secondaryGradient.colors.first
                                .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8)),
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
                          child: const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$points points earned',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              const Text(
                                'Right now they only live on this device.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const _BenefitRow(
                  icon: Icons.leaderboard_rounded,
                  text: 'Officially join the leaderboard rankings'),
              const SizedBox(height: 10),
              const _BenefitRow(
                  icon: Icons.card_giftcard_rounded,
                  text: "Redeem rewards without losing your balance"),
              const SizedBox(height: 10),
              const _BenefitRow(
                  icon: Icons.smartphone_rounded,
                  text: 'Sign back in on any device to keep playing'),
              const SizedBox(height: 26),
              FunButton(
                label: 'Register',
                onPressed: () => _register(context),
                gradient: palette.secondaryGradient,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Row(
      children: [
        Icon(icon, size: 20, color: palette.textDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textDark, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
