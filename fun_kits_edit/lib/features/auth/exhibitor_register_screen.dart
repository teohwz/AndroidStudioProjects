import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../app/routes.dart';
import '../../shared/widgets/fun_button.dart';

/// The ONLY way an exhibitor account is ever created — replaces the old
/// open organizer self-registration (RegisterScreen, role: 'admin'). A
/// Super Admin generates a single-use invite code tied to one specific
/// booth (see ManageBoothsScreen); an exhibitor enters it here alongside
/// their own email/password/display name to claim that booth.
class ExhibitorRegisterScreen extends StatefulWidget {
  const ExhibitorRegisterScreen({super.key});

  @override
  State<ExhibitorRegisterScreen> createState() =>
      _ExhibitorRegisterScreenState();
}

class _ExhibitorRegisterScreenState extends State<ExhibitorRegisterScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final error = await auth.registerExhibitor(
      code: _codeCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else if (mounted) {
      // A freshly-redeemed invite always makes this an exhibitor account —
      // send them to their own Dashboard, not the visitor Home screen (a
      // real bug: the account itself was always correctly created with
      // role: 'exhibitor', but this screen used to land everyone on Home
      // regardless, which made a brand-new exhibitor look/feel like they'd
      // registered as a visitor).
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.exhibitorDashboard, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A1A2E);
    const labelColor = Colors.white70;
    const subtitleColor = Colors.white60;
    const gradient = LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF2D2D3A)],
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
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Exhibitor Registration',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text('Claim your booth with your invite code',
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
                            "Don't have a code? Ask your event organizer / "
                            'Super Admin — exhibitor accounts can only be '
                            'created with one.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  _label('Invite Code', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2),
                    decoration: _inputDeco('e.g. AB3D9F2K'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Invite code is required' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Display Name', labelColor),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Your name / booth contact'),
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
                    validator: (v) => v!.isEmpty ? 'Email is required' : null,
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
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 32),

                  Consumer<AuthService>(
                    builder: (_, auth, __) => FunButton(
                      label: 'Claim My Booth',
                      isLoading: auth.isLoading,
                      onPressed: _register,
                      gradient: gradient,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: subtitleColor),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                  color: Color(0xFF8B80FF),
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
                const BorderSide(color: Color(0xFF8B80FF), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
}
