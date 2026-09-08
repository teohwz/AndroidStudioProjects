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
  String _selectedRole = 'visitor';

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
      // Route based on the role they registered with
      final destination = _selectedRole == 'admin'
          ? AppRoutes.adminDashboard
          : AppRoutes.home;
      Navigator.pushReplacementNamed(context, destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _selectedRole == 'admin';

    // Theme colors swap based on selected role
    final accentColor  = isAdmin ? AppColors.textDark   : AppColors.primary;
    final gradient     = isAdmin ? _adminGradient        : AppColors.secondaryGradient;
    final bgColor      = isAdmin ? const Color(0xFF1A1A2E) : AppColors.backgroundLight;
    final titleColor   = isAdmin ? Colors.white          : AppColors.textDark;
    final subtitleColor= isAdmin ? Colors.white60        : AppColors.textMedium;
    final labelColor   = isAdmin ? Colors.white70        : AppColors.textDark;

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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isAdmin
                        ? _AdminHeader(key: const ValueKey('admin'))
                        : _VisitorHeader(key: const ValueKey('visitor')),
                  ),
                  const SizedBox(height: 28),

                  // ── Role Picker ───────────────────────────────────────
                  _label('I am a...', labelColor),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          value: 'visitor',
                          selected: _selectedRole == 'visitor',
                          emoji: '🎟',
                          title: 'Visitor',
                          subtitle: 'Explore & play games',
                          activeColor: AppColors.primary,
                          darkBg: false,
                          onTap: () => setState(() => _selectedRole = 'visitor'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          value: 'admin',
                          selected: _selectedRole == 'admin',
                          emoji: '🛠',
                          title: 'Organizer',
                          subtitle: 'Manage exhibitors',
                          activeColor: const Color(0xFF8B80FF),
                          darkBg: false,
                          onTap: () => setState(() => _selectedRole = 'admin'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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

// ── Visitor header ─────────────────────────────────────────────────────────
class _VisitorHeader extends StatelessWidget {
  const _VisitorHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Create Account 🎪',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        SizedBox(height: 6),
        Text('Join the fun exhibition experience!',
            style: TextStyle(color: AppColors.textMedium)),
      ],
    );
  }
}

// ── Admin header ───────────────────────────────────────────────────────────
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({super.key});
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

// ── Role card ──────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.value,
    required this.selected,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.activeColor,
    required this.darkBg,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final String emoji;
  final String title;
  final String subtitle;
  final Color activeColor;
  final bool darkBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withOpacity(0.18)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? activeColor : Colors.white.withOpacity(0.15),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected ? activeColor : AppColors.textDark)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? activeColor.withOpacity(0.7) : AppColors.textMedium)),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? activeColor : Colors.transparent,
                border: Border.all(
                  color: selected ? activeColor : const Color(0xFFE0DFFF),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
