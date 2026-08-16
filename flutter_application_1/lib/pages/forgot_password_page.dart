import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/api_service.dart';


class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {

  int _step = 1; // 1 = email, 2 = otp, 3 = new password

  final _emailCtrl    = TextEditingController();
  final _otpCtrls     = List.generate(6, (_) => TextEditingController());
  final _otpFocuses   = List.generate(6, (_) => FocusNode());
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading       = false;
  bool _showPass      = false;
  bool _showConfirm   = false;
  String? _error;
  String  _email      = '';
  String  _otp        = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpFocuses) { f.dispose(); }
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Check email exists then send OTP ────────────────────────────────
  // CHANGED: Backend now returns 404 if email not found.
  // If the email does not exist in the database, ApiException is thrown,
  // the error is shown inline, and the user stays on Step 1.
  // Only a real registered email proceeds to Step 2.
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.forgotPassword(email);
      // Only reaches here if backend confirmed the email exists and sent the OTP.
      setState(() { _email = email; _step = 2; });
    } on ApiException catch (e) {
      // Covers both "email not found" (404) and any other API error.
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 2: Verify OTP against the backend ──────────────────────────────────
  // CHANGED: Was a synchronous void that only checked local digit count.
  // Now async — calls POST /auth/verify-reset-otp before proceeding.
  // If the OTP is invalid or expired the backend returns 400, the boxes
  // are cleared, the error is shown, and the user stays on Step 2.
  // Only a backend-confirmed valid OTP unlocks Step 3.
  Future<void> _confirmOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.verifyResetOtp(code);
      // Backend confirmed the OTP is valid — safe to proceed to Step 3.
      if (mounted) setState(() { _otp = code; _step = 3; });
    } on ApiException catch (e) {
      // Wrong or expired OTP — clear boxes and show error on Step 2.
      for (final c in _otpCtrls) { c.clear(); }
      if (mounted) {
        _otpFocuses[0].requestFocus();
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 3: Reset password using verified OTP ───────────────────────────────
  // Unchanged in logic. The OTP is verified a second time server-side here
  // and marked as used — correct double-validation by design.
  Future<void> _resetPassword() async {
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.resetPassword(_otp, pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset! Please log in.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        // OTP was rejected server-side — send back to OTP entry.
        if (e.message.toLowerCase().contains('invalid') ||
            e.message.toLowerCase().contains('expired')) {
          _step = 2;
          for (final c in _otpCtrls) { c.clear(); }
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── OTP box auto-advance / auto-submit ──────────────────────────────────────
  // CHANGED: Added _loading guard on auto-submit to prevent double API calls
  // if the user types the 6th digit while a verification is already in flight.
  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocuses[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocuses[index - 1].requestFocus();
    }
    // Auto-submit only when all 6 filled AND not already verifying.
    if (_otpCtrls.every((c) => c.text.length == 1) && !_loading) {
      _confirmOtp();
    }
  }

  void _goBack() {
    if (_step == 1) {
      Navigator.pop(context);
    } else {
      setState(() { _step -= 1; _error = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: switch (_step) {
              1 => _buildEmailStep(),
              2 => _buildOtpStep(),
              _ => _buildPasswordStep(),
            },
          ),
        ),
      ),
    );
  }

  // ── Step 1 UI ───────────────────────────────────────────────────────────────
  Widget _buildEmailStep() => Column(
    key: const ValueKey(1),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepIndicator(1),
      const SizedBox(height: 24),
      const Text('Forgot Password',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Enter your registered email address and we\'ll send you a verification code.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
      const SizedBox(height: 36),
      _label('EMAIL'),
      const SizedBox(height: 8),
      _inputBox(
        controller: _emailCtrl,
        hint: 'your@email.com',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        onSubmitted: (_) => _sendOtp(),
      ),
      if (_error != null) _errorText(_error!),
      const SizedBox(height: 28),
      _primaryButton(
        label: 'Send Code',
        icon: Icons.send_rounded,
        onTap: _sendOtp,
      ),
    ],
  );

  // ── Step 2 UI ───────────────────────────────────────────────────────────────
  Widget _buildOtpStep() => Column(
    key: const ValueKey(2),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepIndicator(2),
      const SizedBox(height: 24),
      const Text('Enter Code',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      RichText(text: TextSpan(
        style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
        children: [
          const TextSpan(text: 'We sent a 6-digit code to\n'),
          TextSpan(
            text: _email,
            style: const TextStyle(color: AppColors.primary,
                fontWeight: FontWeight.w700),
          ),
        ],
      )),
      const SizedBox(height: 36),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => _otpBox(i)),
      ),

      if (_error != null) _errorText(_error!),
      const SizedBox(height: 28),

      // CHANGED: Button now triggers async _confirmOtp which calls the backend.
      // Button label reflects the verification action clearly.
      _primaryButton(
        label: 'Verify Code',
        icon: Icons.verified_rounded,
        onTap: _confirmOtp,
      ),
      const SizedBox(height: 16),

      Center(child: TextButton(
        onPressed: _loading ? null : () async {
          setState(() {
            _error = null;
            for (final c in _otpCtrls) { c.clear(); }
          });
          await _sendOtp();
          if (mounted) setState(() => _step = 2);
        },
        child: const Text('Resend Code',
            style: TextStyle(color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
      )),
    ],
  );

  Widget _otpBox(int index) => SizedBox(
    width: 46, height: 56,
    child: TextField(
      controller: _otpCtrls[index],
      focusNode: _otpFocuses[index],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 22, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: (v) => _onOtpChanged(v, index),
    ),
  );

  // ── Step 3 UI ───────────────────────────────────────────────────────────────
  Widget _buildPasswordStep() => Column(
    key: const ValueKey(3),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepIndicator(3),
      const SizedBox(height: 24),
      const Text('New Password',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Choose a strong password for your account.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
      const SizedBox(height: 36),

      _label('NEW PASSWORD'),
      const SizedBox(height: 8),
      _inputBox(
        controller: _passCtrl,
        hint: '••••••••',
        icon: Icons.lock_outline_rounded,
        obscure: !_showPass,
        suffix: IconButton(
          icon: Icon(
            _showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textMuted, size: 20,
          ),
          onPressed: () => setState(() => _showPass = !_showPass),
        ),
      ),
      const SizedBox(height: 16),

      _label('CONFIRM PASSWORD'),
      const SizedBox(height: 8),
      _inputBox(
        controller: _confirmCtrl,
        hint: '••••••••',
        icon: Icons.lock_outline_rounded,
        obscure: !_showConfirm,
        onSubmitted: (_) => _resetPassword(),
        suffix: IconButton(
          icon: Icon(
            _showConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textMuted, size: 20,
          ),
          onPressed: () => setState(() => _showConfirm = !_showConfirm),
        ),
      ),
      const SizedBox(height: 8),
      const Text('At least 8 characters',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted)),

      if (_error != null) _errorText(_error!),
      const SizedBox(height: 28),

      _primaryButton(
        label: 'Reset Password',
        icon: Icons.check_circle_rounded,
        onTap: _resetPassword,
      ),
    ],
  );

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _stepIndicator(int current) => Row(
    children: List.generate(3, (i) {
      final done   = i + 1 < current;
      final active = i + 1 == current;
      return Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:  active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? AppColors.primary : AppColors.cardBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (i < 2) const SizedBox(width: 6),
      ]);
    }),
  );

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 1.8));

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: _loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primaryGlow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _loading
          ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.black, strokeWidth: 2.5))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  )),
            ]),
    ),
  );

  Widget _errorText(String msg) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.error, size: 14),
      const SizedBox(width: 6),
      Expanded(
        child: Text(msg,
            style: const TextStyle(
                color: AppColors.error, fontSize: 12)),
      ),
    ]),
  );
}
