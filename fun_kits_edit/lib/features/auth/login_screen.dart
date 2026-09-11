import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.textDark,
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
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.celebration_rounded,
                        size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text('Fun Kits', style: theme.textTheme.displayMedium),
                ),
                Center(
                  child: Text('Organizer & exhibitor sign-in',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.textMedium)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Visitors don\'t need an account — just scan a booth QR.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.textMedium)),
                  ),
                ),
                const SizedBox(height: 40),
                Text('Email', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(context, 'Enter your email'),
                  validator: (v) =>
                      v!.isEmpty ? 'Email is required' : null,
                ),
                const SizedBox(height: 20),
                Text('Password', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration:
                      _inputDecoration(context, 'Enter your password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
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
                    gradient: palette.primaryGradient,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.register),
                    child: Text.rich(
                      TextSpan(
                        text: 'Have an exhibitor invite code? ',
                        style: TextStyle(color: palette.textMedium),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
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
                      child: Text(
                        'Not exhibitors? Change role',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: palette.textMedium),
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

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.textMedium),
      filled: true,
      fillColor: palette.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}
