import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import 'verify_otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePass = true, _obscureConfirm = true, _loading = false;
  bool _privacyAccepted = false;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset>  _slide;

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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose(); 
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    final name      = '$firstName $lastName'.trim();
    final email   = _emailCtrl.text.trim();
    final phone   = _phoneCtrl.text.trim();
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

   if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _msg("Please fill in all required fields", error: true); return;
    }
    if (pass != confirm) { _msg("Passwords do not match", error: true); return; }
    if (pass.length < 8)  { _msg("Password must be at least 8 characters", error: true); return; }
    if (!_privacyAccepted) {
      _msg("Please agree to the Privacy Policy to continue", error: true); return;
    }

    setState(() => _loading = true);
    try {
      await ApiService.register(
      firstName: firstName,
      lastName:  lastName,
      email:     email,
      password:  pass,
      phone:     phone.isNotEmpty ? phone : null,
      privacyAccepted: _privacyAccepted,
    );
      if (!mounted) return;
      _showSuccessDialog(email);
    } on ApiException catch (e) {
      _msg(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(String email) {
    // Navigate to OTP verification screen instead of showing a dialog
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyOtpPage(
          email:    email,
          fullName: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
        ),
      ),
    );
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [
      Icon(error ? Icons.error_outline : Icons.check_circle_outline,
          color: error ? AppColors.error : AppColors.success, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Positioned(top: -80, left: -80, child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppColors.primary.withOpacity(0.12), Colors.transparent])),
        )),
        SafeArea(child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 32),
              const Text("Create\nAccount", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
              const SizedBox(height: 8),
              const Text("Join DI2's Micos Bikeshop today 🚴", style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 36),

              Row(children: [
             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             _label("FIRST NAME *"),
            const SizedBox(height: 8),
             _field(controller: _firstNameCtrl, hint: "Juan", icon: Icons.person_outline_rounded, type: TextInputType.name),
           ])),
            const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               _label("LAST NAME *"),
            const SizedBox(height: 8),
                _field(controller: _lastNameCtrl, hint: "dela Cruz", icon: Icons.person_outline_rounded, type: TextInputType.name),
          ])),
         ]),
              const SizedBox(height: 18),

              _label("EMAIL *"),
              const SizedBox(height: 8),
              _field(controller: _emailCtrl, hint: "your@email.com", icon: Icons.mail_outline_rounded, type: TextInputType.emailAddress),
              const SizedBox(height: 18),

              _label("PHONE (optional)"),
              const SizedBox(height: 8),
              _field(controller: _phoneCtrl, hint: "09XXXXXXXXX", icon: Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 18),

              _label("PASSWORD * (min. 8 chars)"),
              const SizedBox(height: 8),
              _field(
                controller: _passCtrl, hint: "••••••••",
                icon: Icons.lock_outline_rounded, obscure: _obscurePass,
                suffix: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 18),

              _label("CONFIRM PASSWORD *"),
              const SizedBox(height: 8),
              _field(
                controller: _confirmCtrl, hint: "Repeat password",
                icon: Icons.lock_outline_rounded, obscure: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: () => setState(() => _privacyAccepted = !_privacyAccepted),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: Checkbox(
                      value: _privacyAccepted,
                      onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
                      activeColor: AppColors.primary,
                      checkColor: Colors.black,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                        children: [
                          const TextSpan(text: "I agree that my personal information including "
                              "name, contact details, and delivery address may be used by "
                              "Mico's Bike Shop for order fulfillment and shop management "
                              "purposes in accordance with the "),
                          TextSpan(
                            text: "Data Privacy Act of 2012 (RA 10173)",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: (_loading || !_privacyAccepted) ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 24),

              Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Already have an account? ", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("Sign in", style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ])),
              const SizedBox(height: 20),
            ]),
          ),
        ))),
      ]),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.8));

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, TextInputType type = TextInputType.text, Widget? suffix}) =>
    Container(
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