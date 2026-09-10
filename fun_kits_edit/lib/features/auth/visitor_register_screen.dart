import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../app/routes.dart';
import '../../shared/widgets/fun_button.dart';
import 'visitor_login_screen.dart';

/// Visitor registration — the counterpart to [ExhibitorRegisterScreen],
/// same dark-card layout, just re-colored (coral/pink instead of purple) so
/// the two read as related-but-distinct at a glance. This is what a
/// brand-new visitor sees from [RoleChoiceScreen]'s "I am a Visitor" button
/// — never [SaveProgressScreen], which is reserved for the *later*,
/// in-context prompt (wanting to rank on the leaderboard or redeem points)
/// once someone already has points at stake. Both ultimately call
/// [AuthService.linkEmail] under the hood, but are kept as separate screens
/// with separate framing since the audience and moment are different.
class VisitorRegisterScreen extends StatefulWidget {
  const VisitorRegisterScreen({super.key, this.showSkip = false});

  /// True only the first time someone ever uses the app — no anonymous or
  /// real account existed yet at the moment RoleChoiceScreen's "I am a
  /// Visitor" card was tapped (see role_choice_screen.dart's
  /// `hadNoAccountYet`). The one case where "Skip — Continue as Guest" is
  /// shown. Every other path that reaches this screen — Home's Register
  /// menu item, Save My Points, registration-required prompts, the Visitor
  /// sign-in screen's Register link, Switch Role → I am a Visitor, and even
  /// a return trip to Role Choice by a visitor who already has an
  /// anonymous account — leaves this false, so the button stays hidden.
  final bool showSkip;

  @override
  State<VisitorRegisterScreen> createState() => _VisitorRegisterScreenState();
}

class _VisitorRegisterScreenState extends State<VisitorRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    // The anonymous session already exists by the time this screen is
    // reached (RoleChoiceScreen calls ensureVisitorSession() first) —
    // linking keeps the same uid, so nothing earned so far is lost.
    final error = await auth.linkEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    }
  }

  /// Guest-fallback — this screen gates first entry from RoleChoiceScreen,
  /// so a way to proceed without registering is essential.
  Future<void> _skip() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A1A2E);
    const labelColor = Colors.white70;
    const subtitleColor = Colors.white60;
    const gradient = LinearGradient(
      colors: [Color(0xFFFF6584), Color(0xFF2D2D3A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
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
                        child: const Icon(Icons.celebration_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Visitor Registration 🎟️',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text('Save your points and join the leaderboard',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                          ],
                        ),
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
                            "Totally optional — you can keep playing as a "
                            'guest, but a saved account keeps your points '
                            'safe and lets you redeem rewards.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  _label('Display Name', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Your name'),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Email', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Email address'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Password', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Min 6 characters').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 32),

                  FunButton(
                    label: 'Create Account',
                    isLoading: _busy,
                    onPressed: _register,
                    gradient: gradient,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const VisitorLoginScreen())),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: subtitleColor),
                          children: [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                  color: Color(0xFFFF8EA3),
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.showSkip)
                    Center(
                      child: TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Skip — Continue as Guest',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: subtitleColor),
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

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFFF8EA3), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
}
