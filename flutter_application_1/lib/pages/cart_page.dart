import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/customization_store.dart';
import '../services/api_service.dart';
import 'checkout_page.dart';
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Map<String, dynamic> _cart = {};
  bool _loading     = true;
  bool _checkingOut = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cart = await ApiService.getCart();
      if (mounted) setState(() { _cart = cart; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

 
  List<Map<String, dynamic>> get _items =>
      (_cart['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  String get _total => (_cart['total'] ?? 0).toString();

  Future<void> _updateQty(int itemId, int qty) async {
    try {
      await ApiService.updateCartItem(itemId, qty);
      _load();
    } on ApiException catch (e) { _msg(e.message, error: true); }
  }

  Future<void> _remove(int itemId) async {
    try {
      await ApiService.removeCartItem(itemId);
      _load();
    } on ApiException catch (e) { _msg(e.message, error: true); }
  }

 Future<void> _checkout() async {
  if (_items.isEmpty) { _msg("Your cart is empty", error: true); return; }
  final placed = await Navigator.push(context, MaterialPageRoute(
    builder: (_) => CheckoutPage.cart(cartItems: _items),
  ));
  if (placed != null) _load(); // in case anything changed
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
        title: const Text("My Cart",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: const Text("Clear Cart?",
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text("Remove all items from your cart?",
                        style: TextStyle(color: AppColors.textMuted)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel",
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Clear",
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true) { await ApiService.clearCart(); _load(); }
              },
              child: const Text("Clear",
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _items.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.textMuted, size: 64),
                  const SizedBox(height: 16),
                  const Text("Your cart is empty",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text("Add some bikes to get started!",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    label: const Text("Browse Catalog"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ]))
              : Column(children: [
                  Expanded(child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _cartItem(_items[i]),
                  )),
                  _bottomBar(),
                ]),
    );
  }

  Widget _cartItem(Map<String, dynamic> item) {
    final img = AppConstants.imageUrl(item['variant_image'] ?? item['image']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: img.isNotEmpty
              ? CachedNetworkImage(
                 imageUrl: img, fit: BoxFit.cover, width: 70, height: 70,
                  errorWidget: (_, _, _) => Container(
                      width: 70, height: 70, color: AppColors.surface,
                      child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 32)))
              : Container(width: 70, height: 70, color: AppColors.surface,
                  child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 32)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
           if (item['variant_type'] != null && item['variant_value'] != null) ...[
           const SizedBox(height: 3),
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
             decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(5)),
             child: Text("${item['variant_type']}: ${item['variant_value']}", style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
           ],
          const SizedBox(height: 4),
          Text("₱${item['price']} each",
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            _qtyBtn(Icons.remove, () {
              final qty = (item['quantity'] as int? ?? 1) - 1;
              if (qty < 1) {
                _remove(item['id'] as int);
              } else {
                _updateQty(item['id'] as int, qty);
              }
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text("${item['quantity']}",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            _qtyBtn(Icons.add, () =>
                _updateQty(item['id'] as int, (item['quantity'] as int? ?? 1) + 1)),
            const Spacer(),
            Text("₱${item['subtotal']}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _remove(item['id'] as int),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
        ),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder)),
      child: Icon(icon, color: AppColors.textPrimary, size: 16),
    ),
  );

  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider))),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("TOTAL",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.5)),
        Text("₱$_total",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary)),
      ]),
      const SizedBox(width: 20),
      Expanded(child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _checkingOut ? null : _checkout,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _checkingOut
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text("Place Order",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
      )),
    ]),
  );
}
