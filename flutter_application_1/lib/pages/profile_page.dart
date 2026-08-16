import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool get _addressComplete =>
    (_user?['address_city'] ?? '').toString().trim().isNotEmpty &&
    (_user?['address_street'] ?? '').toString().trim().isNotEmpty;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await ApiService.getProfile();
      if (mounted) setState(() { _user = user; _loading = false; });
    } catch (_) {
      final cached = await AuthService.getUser();
      if (mounted) setState(() { _user = cached; _loading = false; });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Log Out?", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      content: const Text("You will be signed out of your account.", style: TextStyle(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text("Log Out", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
      ],
    ));
    if (ok == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  void _editProfile() {
  if (_user == null) return;
  final firstCtrl = TextEditingController(text: _user!['first_name']?.toString() ?? '');
  final lastCtrl  = TextEditingController(text: _user!['last_name']?.toString() ?? '');
  final phoneCtrl = TextEditingController(text: _user!['phone']?.toString() ?? '');
  bool saving = false;

  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setBS) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
        ]),
        const SizedBox(height: 20),
        _sheetField(firstCtrl, "First Name", Icons.person_outline_rounded),
        const SizedBox(height: 14),
        _sheetField(lastCtrl, "Last Name", Icons.person_outline_rounded),
        const SizedBox(height: 14),
        _sheetField(phoneCtrl, "Phone", Icons.phone_outlined, type: TextInputType.phone),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: saving ? null : () async {
              setBS(() => saving = true);
              try {
                await ApiService.updateProfile({
                  'first_name': firstCtrl.text.trim(),
                  'last_name':  lastCtrl.text.trim(),
                  'phone'    : phoneCtrl.text.trim(),
                });
                if (ctx.mounted) { Navigator.pop(ctx); _load(); }
              } on ApiException catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              } finally { setBS(() => saving = false); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text("Save Changes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    )),
  );
}

  void _editAddress() {
  if (_user == null) return;
  final streetCtrl   = TextEditingController(text: _user?['address_street']?.toString() ?? '');
  final barangayCtrl = TextEditingController(text: _user?['address_barangay']?.toString() ?? '');
  final cityCtrl     = TextEditingController(text: _user?['address_city']?.toString() ?? '');
  final provinceCtrl = TextEditingController(text: _user?['address_province']?.toString() ?? 'Bataan');
  final zipCtrl      = TextEditingController(text: _user?['address_zipcode']?.toString() ?? '');
  final landmarkCtrl = TextEditingController(text: _user?['address_landmark']?.toString() ?? '');
  bool saving = false;

  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setBS) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("Edit Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 20),
          _sheetField(streetCtrl, "Street / House No.", Icons.home_outlined),
          const SizedBox(height: 14),
          _sheetField(barangayCtrl, "Barangay", Icons.map_outlined),
          const SizedBox(height: 14),
          _sheetField(cityCtrl, "City / Municipality", Icons.location_city_outlined),
          const SizedBox(height: 14),
          _sheetField(provinceCtrl, "Province", Icons.public_outlined),
          const SizedBox(height: 14),
          _sheetField(zipCtrl, "Zip Code", Icons.numbers_outlined, type: TextInputType.number),
          const SizedBox(height: 14),
          _sheetField(landmarkCtrl, "Landmark (optional)", Icons.place_outlined),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: saving ? null : () async {
                setBS(() => saving = true);
                try {
                  await ApiService.updateProfile({
                    'address_street':   streetCtrl.text.trim(),
                    'address_barangay': barangayCtrl.text.trim(),
                    'address_city':     cityCtrl.text.trim(),
                    'address_province': provinceCtrl.text.trim(),
                    'address_zipcode':  zipCtrl.text.trim(),
                    'address_landmark': landmarkCtrl.text.trim(),
                  });
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); }
                } on ApiException catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                } finally { setBS(() => saving = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text("Save Address", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    )),
  );
}

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon, {TextInputType type = TextInputType.text}) =>
    Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: TextField(
        controller: ctrl, keyboardType: type,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0, automaticallyImplyLeading: false,
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editProfile)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Avatar
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(color: AppColors.primaryGlow, shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2)),
                  child: Center(child: Text(
                    (_user?['first_name'] ?? 'U').toString()[0].toUpperCase(),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary),
                  )),
                ),
                const SizedBox(height: 16),
                Text('${_user?['first_name'] ?? ''} ${_user?['last_name'] ?? ''}'.trim(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(_user?['email']?.toString() ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 32),

                // Info
                _infoCard("Contact", [
                _infoRow(Icons.phone_outlined, "Phone", _user?['phone']?.toString() ?? 'Not set'),
               ]),
               const SizedBox(height: 12),
               Container(
                padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
               const Text("ADDRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
               const Spacer(),
                  GestureDetector(
                 onTap: _editAddress,
                 child: const Row(children: [
                  Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text("Edit", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                 ]),
                 ),
                 ]),
               const SizedBox(height: 12),
                if (_addressComplete)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
               [
              _user?['address_street'], _user?['address_barangay'],
              _user?['address_city'], _user?['address_province'], _user?['address_zipcode'],
              ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(', '),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
             ),
              if ((_user?['address_landmark'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
             Text("Landmark: ${_user!['address_landmark']}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
             ],
             ])
             else
              const Text("No address saved yet", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ]),
     ),
              const SizedBox(height: 12),

                // Settings menu
                _menuCard("Account Settings", [
                  _menuItem(Icons.lock_outline_rounded, "Change Password", AppColors.info, () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
                 
                ]),
                const SizedBox(height: 32),

                // Logout
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    label: const Text("Log Out", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(" ", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
              ]),
            ),
    );
  }

  void _showAbout() => showDialog(context: context, builder: (_) => AlertDialog(
    backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 32)),
      const SizedBox(height: 16),
      const Text("DI2's Micos Bikeshop", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text("Version 1.0.0", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 8),
      const Text("Your one-stop shop for quality bikes and accessories.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: AppColors.primary)))],
  ));

  Widget _infoCard(String title, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      ...rows,
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: AppColors.primary, size: 16),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
    ]),
  );

  Widget _menuCard(String title, List<Widget> items) => Container(
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
      ),
      ...items.asMap().entries.map((e) => Column(children: [
        if (e.key > 0) const Divider(height: 1, color: AppColors.divider, indent: 52),
        e.value,
      ])),
      const SizedBox(height: 4),
    ]),
  );

  Widget _menuItem(IconData icon, String label, Color iconColor, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ]),
      ),
    );
}
