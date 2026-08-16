import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import 'chat_page.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$label copied!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
       
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: Container(
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              // Gradient background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1a0a00), Color(0xFF2d1500)],
                  ),
                ),
              ),
              // Grid lines
              CustomPaint(painter: _GridPainter()),
              // Glow
              Center(child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withOpacity(0.18), Colors.transparent,
                  ]),
                ),
              )),
              // Logo
             Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary, // Your border color
            width: 0,               // Border thickness
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(65), // Half of the width/height for a perfect circle
          child: Image.asset(
            'assets/images/logo.jpg',
            fit: BoxFit.contain, // Ensures the image fills the circle
          ),
        ),
      ),
      // ... your Text widgets follow here
    
                const SizedBox(height: 10),
                const Text("DI2'S MICO'S BIKESHOP",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 3)),
                const Text("BIKE SHOP",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.primary, letterSpacing: 5)),
              ])),
              // Bottom fade
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 60, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [AppColors.background, Colors.transparent]),
                )),
              ),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Tagline
              const Text(ShopInfo.tagline,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
              const SizedBox(height: 20),

              _sectionTitle("Contact Information"),
              const SizedBox(height: 10),
              _contactCard(context),
              const SizedBox(height: 20),

              
              _sectionTitle("Business Hours"),
              const SizedBox(height: 10),
              _hoursCard(),
              const SizedBox(height: 20),

              
              _sectionTitle("Location"),
              const SizedBox(height: 10),
              _locationCard(context),
              const SizedBox(height: 20),

              
              _sectionTitle("About Us"),
              const SizedBox(height: 10),
              _aboutCard(),
              const SizedBox(height: 30),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 2));

  Widget _contactCard(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(children: [
      _contactRow(context, Icons.location_on_outlined, "Address", ShopInfo.address, AppColors.primary,
          onTap: () {}),
      const Divider(height: 1, color: AppColors.divider, indent: 52),
      _contactRow(context, Icons.phone_outlined, "Phone", ShopInfo.phone, AppColors.success,
          onTap: () => _copy(context, ShopInfo.phone, "Phone number")),
      const Divider(height: 1, color: AppColors.divider, indent: 52),
      _contactRow(context, Icons.email_outlined, "Email", ShopInfo.email, AppColors.info,
          onTap: () => _copy(context, ShopInfo.email, "Email address")),
      const Divider(height: 1, color: AppColors.divider, indent: 52),
      _contactRow(context, Icons.facebook_outlined, "Facebook", "Mico's Bike Shop", const Color(0xFF1877F2),
          onTap: () {}),
    ]),
  );

  Widget _contactRow(BuildContext context, IconData icon, String label,
      String value, Color color, {required VoidCallback onTap}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ])),
          const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
        ]),
      ),
    );

  Widget _hoursCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(children: ShopInfo.hours.asMap().entries.map((e) {
      final h = e.value;
      final isClosed = h['time'] == 'Closed';
      final isLast   = e.key == ShopInfo.hours.length - 1;
      return Column(children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isClosed ? AppColors.error : AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(h['day']!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          Text(h['time']!,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isClosed ? AppColors.error : AppColors.success)),
        ]),
        if (!isLast) const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ]);
    }).toList()),
  );

  Widget _locationCard(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(children: [
      // Fake map preview
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        child: Container(
          height: 140, width: double.infinity,
          color: const Color(0xFF1a2a1a),
          child: Stack(children: [
            CustomPaint(painter: _MapPainter(), child: const SizedBox.expand()),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(ShopInfo.address,
                    style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w700)),
              ),
              Container(
                width: 2, height: 12,
                color: AppColors.primary,
              ),
              Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ])),
          ]),
        ),
      ),
      InkWell(
        onTap: () {
          Clipboard.setData(const ClipboardData(text: ShopInfo.mapsUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Map link copied! Open in Google Maps.")),
          );
        },
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text("Open in Google Maps",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))),
            const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
          ]),
        ),
      ),
    ]),
  );

  Widget _aboutCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: const Text(
      "DI2's Mico's Bike Shop is your trusted local destination for quality bicycles, "
      "spare parts, and accessories in Bataan. We offer a wide selection of bikes for all ages "
      "and riding styles — from mountain bikes to road bikes and everything in between.\n\n"
      "Our team is passionate about cycling and committed to providing excellent service "
      "to every customer. Whether you need a brand new bike, a tune-up, or expert advice, "
      "we've got you covered.",
      style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.7),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22FF6B00)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = const Color(0xFF2a3a2a)..strokeWidth = 8..strokeCap = StrokeCap.round;
    final road2 = Paint()..color = const Color(0xFF223322)..strokeWidth = 5..strokeCap = StrokeCap.round;
    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), road);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), road2);
    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), road);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, size.height), road2);
    // Blocks
    final block = Paint()..color = const Color(0xFF1e2e1e);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.37, size.height * 0.32, size.width * 0.36, size.height * 0.36), const Radius.circular(4)), block);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, size.width * 0.32, size.height * 0.26), const Radius.circular(4)), block);
  }
  @override bool shouldRepaint(_) => false;
}
