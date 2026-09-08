import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Save My Points',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
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
                      gradient: AppColors.secondaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 36)),
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
                  emoji: '🏆',
                  text: 'Officially join the leaderboard rankings'),
              const SizedBox(height: 10),
              const _BenefitRow(
                  emoji: '🎁',
                  text: "Redeem rewards without losing your balance"),
              const SizedBox(height: 10),
              const _BenefitRow(
                  emoji: '📱',
                  text: 'Sign back in on any device to keep playing'),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: () => _register(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Register',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
