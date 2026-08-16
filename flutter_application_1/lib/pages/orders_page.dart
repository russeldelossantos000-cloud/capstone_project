import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/api_service.dart';
import 'write_review_page.dart';
import 'invoice_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await ApiService.getOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) => switch (s) {
    'delivered'  => AppColors.success,
    'shipped'    => const Color(0xFFa78bfa),
    'processing' => AppColors.info,
    'cancelled'  => AppColors.error,
    _            => AppColors.warning,
  };

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0, automaticallyImplyLeading: false,
        title: const Text("My Orders", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _orders.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 64),
                  SizedBox(height: 12),
                  Text("No orders yet", style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text("Your orders will appear here", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  color: AppColors.primary, backgroundColor: AppColors.card,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _orderCard(_orders[i]),
                  ),
                ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'pending').toString();
    final pay    = (o['payment_status'] ?? 'unpaid').toString();
    final color  = _statusColor(status);
    String dateStr = '';
    try { dateStr = DateFormat('MMM d, yyyy').format(DateTime.parse(o['created_at'].toString())); } catch (_) {}

    return GestureDetector(
    onTap: () async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o['id'] as int)));
  _load();
},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(o['reference_number']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'monospace'))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicePage(orderId: o['id'] as int))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_outlined, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text("Invoice", style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.payments_outlined, color: AppColors.textMuted, size: 14),
            const SizedBox(width: 6),
            Text((o['payment_method'] ?? '').toString().toUpperCase().replaceAll('_', ' '),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: pay == 'paid' ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(pay.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pay == 'paid' ? AppColors.success : AppColors.error)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 12),
            const SizedBox(width: 6),
            Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            Text("₱${o['total_amount']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
        ]),
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  const OrderDetailPage({super.key, required this.orderId});
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? _order;
  bool _loading = true;

Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Cancel Order',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            content: const Text('Are you sure you want to cancel this order? This cannot be undone.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep Order', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
        ),
    );

    if (confirm != true || !mounted) return;

    try {
        await ApiService.cancelOrder(_order!['id'] as int);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled.'), backgroundColor: AppColors.error),
        );
        Navigator.pop(context, true); // pop back and signal refresh
    } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
    }
}

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final o = await ApiService.getOrder(widget.orderId);
      if (mounted) setState(() { _order = o; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) => switch (s) {
    'delivered'  => AppColors.success,
    'shipped'    => const Color(0xFFa78bfa),
    'processing' => AppColors.info,
    'cancelled'  => AppColors.error,
    _            => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(_order?['reference_number']?.toString() ?? 'Order Detail',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _order == null
              ? const Center(child: Text("Order not found", style: TextStyle(color: AppColors.textMuted)))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final o      = _order!;
    final items  = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = (o['status'] ?? 'pending').toString();
    final color  = _statusColor(status);
    String dateStr = '';
    try { dateStr = DateFormat('MMMM d, yyyy · h:mm a').format(DateTime.parse(o['created_at'].toString())); } catch (_) {}

    final steps = ['pending', 'processing', 'shipped', 'delivered'];
    final stepIdx = steps.indexOf(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status banner
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(status.toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),

        // Progress stepper (only for active orders)
        if (status != 'cancelled') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) return Expanded(child: Container(height: 2, color: i ~/ 2 < stepIdx ? AppColors.primary : AppColors.divider));
              final si = i ~/ 2;
              final done = si <= stepIdx;
              return Column(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.primary : AppColors.surface, border: Border.all(color: done ? AppColors.primary : AppColors.divider)),
                  child: done ? const Icon(Icons.check_rounded, color: Colors.black, size: 14) : null,
                ),
                const SizedBox(height: 4),
                Text(steps[si], style: TextStyle(fontSize: 9, color: done ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w700)),
              ]);
            })),
          ),
          const SizedBox(height: 16),
        ],

        // Summary
        _section("ORDER SUMMARY", [
          _row("Payment Method", (o['payment_method'] ?? '').toString().toUpperCase().replaceAll('_', ' ')),
          _row("Payment Status", (o['payment_status'] ?? '').toString().toUpperCase(), color: o['payment_status'] == 'paid' ? AppColors.success : AppColors.error),
          _row("Total", "₱${o['total_amount']}", bold: true, color: AppColors.primary),
        ]),

       // Cancel button — only for pending orders
if (status == 'pending') ...[
    const SizedBox(height: 24),
    SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
            onPressed: _cancelOrder,
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
            label: const Text('Cancel Order',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
        ),
    ),
],

        const SizedBox(height: 16),

        // Items
        const Text("ITEMS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 10),
        ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['product_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text("Qty: ${item['quantity']}  ·  ₱${item['price']} each", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (item['variant_type'] != null && item['variant_value'] != null)
                  Text("+ ${item['variant_type']}: ${item['variant_value']}", style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                 ])),
              Text("₱${(double.tryParse(item['price'].toString()) ?? 0) * (int.tryParse(item['quantity'].toString()) ?? 1)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ]),
            if (status == 'delivered') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => WriteReviewPage(
                    productId:   item['product_id'] as int,
                    productName: item['product_name']?.toString() ?? '',
                    orderId:     o['id'] as int,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_outline_rounded, color: AppColors.primary, size: 14),
                    SizedBox(width: 6),
                    Text("Write a Review", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: children),
    ),
  ]);

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]),
  );
}
