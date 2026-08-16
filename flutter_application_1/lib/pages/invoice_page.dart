import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/api_service.dart';

class InvoicePage extends StatefulWidget {
  final int orderId;
  const InvoicePage({super.key, required this.orderId});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await ApiService.getOrder(widget.orderId);
      if (mounted) setState(() { _order = o; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? s) {
    if (s == null) return '—';
    try { return DateFormat('MMMM d, yyyy  h:mm a').format(DateTime.parse(s)); }
    catch (_) { return s; }
  }

  double _itemSubtotal(Map<String, dynamic> item) =>
      (double.tryParse(item['price']?.toString() ?? '0') ?? 0) *
      (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("Invoice", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: "Copy reference number",
            onPressed: () {
              if (_order != null) {
                Clipboard.setData(ClipboardData(text: _order!['reference_number']?.toString() ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reference number copied!")),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _order == null
              ? const Center(child: Text("Could not load invoice", style: TextStyle(color: AppColors.textMuted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildReceipt(),
                ),
    );
  }

  Widget _buildReceipt() {
    final o      = _order!;
    final items  = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = (o['status'] ?? 'pending').toString();
    final payStatus = (o['payment_status'] ?? 'unpaid').toString();
    final total  = double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0;

    final statusColor = {
      'delivered': AppColors.success, 'shipped': const Color(0xFFa78bfa),
      'processing': AppColors.info,   'cancelled': AppColors.error,
    }[status] ?? AppColors.warning;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(children: [
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
          width: 90,    
          height: 90,
          fit: BoxFit.fill,
        ),
        ),
      ),
          const SizedBox(height: 12),
          const Text(ShopInfo.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text(ShopInfo.tagline,
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(ShopInfo.address,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(ShopInfo.phone,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      ),
      const SizedBox(height: 14),

   
      Row(children: [
        const Expanded(
          child: Text("OFFICIAL INVOICE",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, letterSpacing: 2)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Text(status.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5)),
        ),
      ]),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(children: [
          _infoRow("Reference No.", o['reference_number']?.toString() ?? '—',
              valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.primary, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          _infoRow("Date Issued", _fmtDate(o['created_at']?.toString())),
          const SizedBox(height: 8),
          _infoRow("Payment Method",
              (o['payment_method'] ?? '').toString().toUpperCase().replaceAll('_', ' ')),
          const SizedBox(height: 8),
          _infoRow("Payment Status", payStatus.toUpperCase(),
              valueColor: payStatus == 'paid' ? AppColors.success : AppColors.error),
        ]),
      ),
      const SizedBox(height: 14),

      const Text("ITEMS ORDERED",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 2)),
      const SizedBox(height: 10),

      Container(
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(children: const [
              Expanded(child: Text("Item", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1))),
              SizedBox(width: 40, child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted))),
              SizedBox(width: 10),
              SizedBox(width: 80, child: Text("Subtotal", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted))),
            ]),
          ),

          // Item rows
          ...items.asMap().entries.map((e) {
            final i    = e.value;
            final sub  = _itemSubtotal(i);
            final isLast = e.key == items.length - 1;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i['product_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text("@ ₱${i['price']} each",
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    if (i['variant_type'] != null && i['variant_value'] != null) ...[
                      const SizedBox(height: 3),
                    Row(children: [
                    const Icon(Icons.tune_rounded, size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(child: Text("${i['variant_type']}: ${i['variant_value']}",
                   style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600))),
                    ]),
                  ],
                  ])),
                  SizedBox(width: 40,
                      child: Text("×${i['quantity']}", textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  const SizedBox(width: 10),
                  SizedBox(width: 80,
                      child: Text("₱${sub.toStringAsFixed(2)}", textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                ]),
              ]),
            );
          }),

          // Total row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGlow.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              border: const Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(children: [
              const Expanded(child: Text("TOTAL AMOUNT",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: 0.5))),
              Text("₱${total.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Payment status banner ─────────────────────────────────────────────
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: payStatus == 'paid'
              ? AppColors.success.withOpacity(0.1)
              : AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: payStatus == 'paid'
                ? AppColors.success.withOpacity(0.3)
                : AppColors.warning.withOpacity(0.3),
          ),
        ),
        child: Row(children: [
          Icon(
            payStatus == 'paid' ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: payStatus == 'paid' ? AppColors.success : AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              payStatus == 'paid' ? "Payment Confirmed" : "Awaiting Payment",
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: payStatus == 'paid' ? AppColors.success : AppColors.warning,
              ),
            ),
            Text(
              payStatus == 'paid'
                  ? "Thank you for your payment!"
                  : "Please settle payment upon pickup or delivery.",
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Footer ────────────────────────────────────────────────────────────
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(children: [
          const Text("Thank you for shopping at Mico's Bike Shop!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text("This serves as your official receipt.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),
          Text(ShopInfo.address,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text("${ShopInfo.phone}  ·  ${ShopInfo.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
      const SizedBox(height: 30),
    ]);
  }

  Widget _infoRow(String label, String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    const Spacer(),
    Text(value,
        style: valueStyle ?? TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: valueColor ?? AppColors.textPrimary,
        )),
  ]);
}
