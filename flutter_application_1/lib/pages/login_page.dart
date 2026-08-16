import 'package:flutter/material.dart';
import 'dart:async';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _loading   = false;
  late AnimationController _anim;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _msg("Please fill in all fields", error: true); return;
    }

    setState(() => _loading = true);

    try {
      final res = await ApiService.login(email, password);

      // Save token + user to local storage
      await AuthService.saveSession(res['token'], res['user']);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));

    } on ApiException catch (e) {
      if (!mounted) return;
      // Handle email unverified case
      if (e.statusCode == 403 && e.message.contains('verify')) {
        _showUnverifiedDialog(email);
      } else {
        _msg(e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUnverifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Email Not Verified',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text(
          'Please verify your email before logging in. Check your inbox for the verification link.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.resendVerification(email);
                _msg("Verification email resent!");
              } on ApiException catch (e) {
                _msg(e.message, error: true);
              }
            },
            child: const Text('Resend Email', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? AppColors.error : AppColors.success, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // Background glow
        Positioned(top: -100, right: -80, child: _glow(300, AppColors.primary, 0.15)),
        Positioned(bottom: -60, left: -60, child: _glow(200, AppColors.primary, 0.08)),

        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 20),
                  // Brand
                  Center(child: Column(children:  [
                  Container(
        padding: const EdgeInsets.all(0), // Space between image and border
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary, // Your border color
            width: 0.5, // Your border width
          ),
          borderRadius: BorderRadius.circular(45), // Optional: rounds the border corners
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45), // Match this to the container's borderRadius for a perfect circle
        child: Image.asset(
          'assets/images/logo.jpg', 
          width: 150,    
          height: 140,
          fit: BoxFit.fill,
        ),
        ),
      ),
                    const SizedBox(height: 16),
                    const Text("DI2'S MICO'S", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 4)),
                    const Text("BIKESHOP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 6)),
                  ])),
                  const SizedBox(height: 56),

                  const Text(" ", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text(" ", style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 36),

                  _label("EMAIL"),
                  const SizedBox(height: 8),
                  _field(controller: _emailCtrl, hint: "your@email.com", icon: Icons.mail_outline_rounded, type: TextInputType.emailAddress),
                  const SizedBox(height: 20),

                  _label("PASSWORD"),
                  const SizedBox(height: 8),
                  _field(
                    controller: _passwordCtrl, hint: "••••••••",
                    icon: Icons.lock_outline_rounded, obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                      child: const Text("Forgot password?", style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Login button
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                          : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                      child: const Text("Create one", style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glow(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.8));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    Widget? suffix,
  }) => Container(
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
    child: TextField(
      controller: controller, obscureText: obscure, keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix, border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );
}
