import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../app/routes.dart';
import '../../shared/widgets/fun_button.dart';
import 'role_choice_screen.dart';

// ─── LOGIN SCREEN ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.hideChangeRole = false});

  /// True when this screen was reached via a visitor's "Switch Role"
  /// action (RoleChoiceScreen with hideRole: 'visitor') — in that case the
  /// only way "in" here already was a deliberate visitor-to-exhibitor
  /// switch, so the "Not exhibitors? Change role" way back out is hidden.
  /// Left false (the default) everywhere else, including this screen's own
  /// bootstrap-root case, where the link is the only way out for an
  /// exhibitor who logged out and landed here by mistake.
  final bool hideChangeRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      final auth = context.read<AuthService>();
      final destination = auth.isSuperAdmin
          ? AppRoutes.superAdminDashboard
          : auth.isExhibitor
              ? AppRoutes.exhibitorDashboard
              : AppRoutes.home;
      Navigator.pushReplacementNamed(context, destination);
    }
  }

  /// "Not exhibitors? Change role" — back to [RoleChoiceScreen] (this
  /// screen can be shown as the app's bootstrap screen after an exhibitor
  /// logs out — see app.dart — so it needs a way out for anyone who landed
  /// here by mistake or changed their mind about which role they are).
  /// Pops back to an already-pushed RoleChoiceScreen when one exists on the
  /// stack (e.g. reached via "I am an Exhibitor"), otherwise pushes a fresh
  /// one (e.g. this screen is the bootstrap root).
  void _changeRole() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoleChoiceScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Logo / Title
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.celebration,
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
                  child: Text('Organizer & exhibitor sign-in',
                      style: TextStyle(
                          color: AppColors.textMedium, fontSize: 14)),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Visitors don\'t need an account — just scan a booth QR.',
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
                  validator: (v) =>
                      v!.isEmpty ? 'Email is required' : null,
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
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 36),
                Consumer<AuthService>(
                  builder: (_, auth, __) => FunButton(
                    label: 'Login',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                    gradient: AppColors.primaryGradient,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.register),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Have an exhibitor invite code? ',
                        style: TextStyle(color: AppColors.textMedium),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!widget.hideChangeRole)
                  Center(
                    child: TextButton(
                      onPressed: _changeRole,
                      child: const Text(
                        'Not exhibitors? Change role',
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
              const BorderSide(color: Color(0xFFE0DFFF), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
}
