import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../app/routes.dart';
import '../../shared/widgets/fun_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool   _obscure     = true;
  // Visitors no longer create accounts — this screen only creates organizer
  // (admin) accounts for exhibition staff.
  static const String _selectedRole = 'admin';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final error = await auth.register(
      email:       _emailCtrl.text.trim(),
      password:    _passwordCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role:        _selectedRole,
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    const isAdmin = true;

    // Organizer theme
    final gradient     = _adminGradient;
    final bgColor      = const Color(0xFF1A1A2E);
    final labelColor   = Colors.white70;
    final subtitleColor= Colors.white60;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: isAdmin ? Colors.white : AppColors.textDark),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────
                  const _AdminHeader(),
                  const SizedBox(height: 28),

                  // ── Fields ────────────────────────────────────────────
                  _label('Display Name', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: isAdmin ? Colors.white : AppColors.textDark),
                    decoration: _inputDeco('Your name', isAdmin),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Email', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isAdmin ? Colors.white : AppColors.textDark),
                    decoration: _inputDeco('Email address', isAdmin),
                    validator: (v) => v!.isEmpty ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Password', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: TextStyle(color: isAdmin ? Colors.white : AppColors.textDark),
                    decoration: _inputDeco('Min 6 characters', isAdmin).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: isAdmin ? Colors.white54 : AppColors.textMedium,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 32),

                  // ── Submit ────────────────────────────────────────────
                  Consumer<AuthService>(
                    builder: (_, auth, __) => FunButton(
                      label: isAdmin ? 'Create Organizer Account' : 'Create Account',
                      isLoading: auth.isLoading,
                      onPressed: _register,
                      gradient: gradient,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: subtitleColor),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                  color: isAdmin
                                      ? const Color(0xFF8B80FF)
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(text,
      style: TextStyle(fontWeight: FontWeight.w700, color: color));

  InputDecoration _inputDeco(String hint, bool dark) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: dark ? Colors.white38 : AppColors.textMedium),
        filled: true,
        fillColor: dark ? Colors.white.withOpacity(0.07) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: dark
                    ? Colors.white.withOpacity(0.15)
                    : const Color(0xFFE0DFFF),
                width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: dark ? const Color(0xFF8B80FF) : AppColors.primary,
                width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );

  static const _adminGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF2D2D3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Admin header ───────────────────────────────────────────────────────────
class _AdminHeader extends StatelessWidget {
  const _AdminHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organizer Account 🛠',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Manage exhibitions & exhibitors',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Organizers can add exhibitors, manage quizzes and lucky draws.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
