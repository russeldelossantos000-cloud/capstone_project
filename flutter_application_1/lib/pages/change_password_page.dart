import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true, _obscureNew = true, _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final current = _currentCtrl.text.trim();
    final newPass  = _newCtrl.text.trim();
    final confirm  = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _msg("Please fill in all fields", error: true); return;
    }
    if (newPass.length < 8) {
      _msg("New password must be at least 8 characters", error: true); return;
    }
    if (newPass != confirm) {
      _msg("Passwords do not match", error: true); return;
    }

    setState(() => _loading = true);
    try {
      
      await ApiService.updateProfile({'password': newPass});
      if (!mounted) return;
      _msg("Password changed successfully!");
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _msg(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text(
                "Your new password must be at least 8 characters long.",
                style: TextStyle(color: AppColors.info, fontSize: 13, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 32),

          _label("CURRENT PASSWORD"),
          const SizedBox(height: 8),
          _field(_currentCtrl, "Enter current password", _obscureCurrent,
              () => setState(() => _obscureCurrent = !_obscureCurrent)),
          const SizedBox(height: 20),

          _label("NEW PASSWORD"),
          const SizedBox(height: 8),
          _field(_newCtrl, "Enter new password", _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 20),

          _label("CONFIRM NEW PASSWORD"),
          const SizedBox(height: 8),
          _field(_confirmCtrl, "Repeat new password", _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm)),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _change,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : const Text("Change Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.8));

  Widget _field(TextEditingController ctrl, String hint, bool obscure, VoidCallback toggleObscure) =>
    Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: TextField(
        controller: ctrl, obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textMuted, size: 20),
            onPressed: toggleObscure,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
}
