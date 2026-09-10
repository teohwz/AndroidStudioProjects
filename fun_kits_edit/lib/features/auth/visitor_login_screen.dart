import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../app/routes.dart';
import '../../shared/widgets/fun_button.dart';
import 'role_choice_screen.dart';
import 'visitor_register_screen.dart';

/// Visitor sign-in — the counterpart to the organizer/exhibitor
/// [LoginScreen], same layout and structure, just re-colored (coral/pink
/// instead of purple) so the two are visually distinguishable at a glance.
/// Reached two ways:
/// - As the app's bootstrap screen after a registered (email-linked)
///   visitor logs out (see app.dart / AuthService.lastKnownMode), or after
///   Home's own Logout button clears the stack down to this route — the
///   sole route either way, so "Change Role?"/"Skip" are shown here (see
///   `build()`'s `canPop` check) since there's no other way out.
/// - Pushed on top of [VisitorRegisterScreen] via its "Sign in" link, for a
///   visitor who already has an anonymous session and just wants to log
///   into an existing saved-points account — "Change Role?"/"Skip" are
///   hidden here, since a Back button already leads out and the account
///   already exists.
class VisitorLoginScreen extends StatefulWidget {
  const VisitorLoginScreen({super.key});

  @override
  State<VisitorLoginScreen> createState() => _VisitorLoginScreenState();
}

class _VisitorLoginScreenState extends State<VisitorLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final error = await auth.login(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text.trim());
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else if (mounted) {
      // A visitor's email could in principle belong to an exhibitor/Super
      // Admin account — route by the actual role that comes back, same as
      // LoginScreen, rather than assuming Home.
      final destination = auth.isSuperAdmin
          ? AppRoutes.superAdminDashboard
          : auth.isExhibitor
              ? AppRoutes.exhibitorDashboard
              : AppRoutes.home;
      // Clears the whole stack either way — this screen can be the sole
      // bootstrap route (post-logout) or pushed on top of Register/Login,
      // and either way a fresh sign-in should land on a clean destination.
      Navigator.of(context)
          .pushNamedAndRemoveUntil(destination, (route) => false);
    }
  }

  /// "Change Role?" — back to [RoleChoiceScreen]. Pops back to an
  /// already-pushed RoleChoiceScreen when one exists on the stack (e.g.
  /// reached via "I am a Visitor"), otherwise pushes a fresh one (e.g. this
  /// screen is the bootstrap root after a registered visitor logs out).
  void _changeRole() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoleChoiceScreen()));
    }
  }

  /// Guest-fallback (this screen can be the app's bootstrap screen after a
  /// registered visitor logs out — see app.dart). Ensures an anonymous
  /// session exists and proceeds to Home.
  Future<void> _skipToGuest() async {
    final auth = context.read<AuthService>();
    await auth.ensureVisitorSession();
    if (!mounted) return;
    if (auth.authFailed) return; // app.dart shows the retry screen instead
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // True only when this screen is the sole route in the stack (the app's
    // bootstrap screen after a registered visitor logs out, or right after
    // Home's Logout clears the stack down to it) — the only case where
    // "Change Role?"/"Skip" are needed, since there's no other way out.
    // When pushed from VisitorRegisterScreen's "Sign in" link, this is
    // false and both stay hidden — the visitor already has an account and
    // a Back button.
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.secondaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Fun Kits',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                ),
                const Center(
                  child: Text('Visitor sign-in',
                      style: TextStyle(
                          color: AppColors.textMedium, fontSize: 14)),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                        "Sign back in to load the points you've already saved.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMedium, fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Email',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Enter your email'),
                  validator: (v) => v!.isEmpty ? 'Email is required' : null,
                ),
                const SizedBox(height: 20),
                const Text('Password',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: _inputDecoration('Enter your password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 36),
                Consumer<AuthService>(
                  builder: (_, auth, __) => FunButton(
                    label: 'Login',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                    gradient: AppColors.secondaryGradient,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const VisitorRegisterScreen())),
                    child: const Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: AppColors.textMedium),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!canPop)
                  Center(
                    child: TextButton(
                      onPressed: _changeRole,
                      child: const Text(
                        'Change Role?',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium),
                      ),
                    ),
                  ),
                if (!canPop)
                  Center(
                    child: TextButton(
                      onPressed: _skipToGuest,
                      child: const Text(
                        'Skip — Continue as Guest',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMedium),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFFE0E8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
}
