import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final String fullName;

  const VerifyOtpPage({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage>
    with SingleTickerProviderStateMixin {
  // 6 separate controllers — one per digit box
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  bool _loading      = false;
  bool _resending    = false;
  String _error      = '';

  late AnimationController _shake;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
        CurvedAnimation(parent: _shake, curve: Curves.elasticIn));
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foci[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final f in _foci)  { f.dispose(); }
    _shake.dispose();
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      _shake.forward(from: 0);
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await ApiService.verifyEmail(_code);
      if (!mounted) return;
      _showSuccess();
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
      // Clear boxes and shake on wrong code
      for (final c in _ctrls) { c.clear(); }
      _foci[0].requestFocus();
      _shake.forward(from: 0);
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = ''; });
    try {
      await ApiService.resendVerification(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("New code sent! Check your email."),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success.withOpacity(0.4))),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 18),
          const Text("Email Verified!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text("Your account is ready. You can now log in.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Go to Login",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4))),
              child: const Icon(Icons.mark_email_unread_outlined,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 24),

            const Text("Check Your Email",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            RichText(text: TextSpan(children: [
              const TextSpan(
                  text: "We sent a 6-digit code to\n",
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.6)),
              TextSpan(
                  text: widget.email,
                  style: const TextStyle(fontSize: 14, color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(height: 36),

            // OTP boxes
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  _shake.isAnimating
                      ? _shakeAnim.value * ((_shake.value * 10).round().isOdd ? 1 : -1)
                      : 0,
                  0,
                ),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
            ),
            const SizedBox(height: 12),

            // Error
            if (_error.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error,
                      style: const TextStyle(color: AppColors.error, fontSize: 13))),
                ]),
              ),
            const SizedBox(height: 28),

            // Verify button
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : const Text("Verify Email",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 20),

            // Resend
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Didn't receive a code? ",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              GestureDetector(
                onTap: _resending ? null : _resend,
                child: _resending
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                    : const Text("Resend",
                        style: TextStyle(color: AppColors.primary, fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ])),
            const SizedBox(height: 8),
            const Center(
              child: Text("Also check your spam/junk folder",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 46, height: 56,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _foci[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.card,
          contentPadding: EdgeInsets.zero,
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
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) {
            // Move to next box
            _foci[i + 1].requestFocus();
          } else if (val.isEmpty && i > 0) {
            // Move back on delete
            _foci[i - 1].requestFocus();
          }
          // Auto-submit when all 6 filled
          if (_code.length == 6 && !_loading) _verify();
        },
      ),
    );
  }
}