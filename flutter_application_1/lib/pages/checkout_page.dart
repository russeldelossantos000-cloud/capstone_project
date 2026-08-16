import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool isCartCheckout;

  const CheckoutPage._({required this.items, required this.isCartCheckout, super.key});

  /// Order Now — single product (+ optional variant), editable quantity.
  factory CheckoutPage.direct({
    required Map<String, dynamic> bike,
    Map<String, dynamic>? selectedVariant,
    int quantity = 1,
  }) {
    final basePrice = double.tryParse(bike['price']?.toString() ?? '0') ?? 0;
    final adj       = double.tryParse(selectedVariant?['price_adjustment']?.toString() ?? '0') ?? 0;
    final stock     = selectedVariant != null
        ? (int.tryParse(selectedVariant['stock']?.toString() ?? '0') ?? 0)
        : (int.tryParse(bike['stock']?.toString() ?? '0') ?? 0);

    return CheckoutPage._(isCartCheckout: false, items: [
      {
        'product_id':    bike['id'],
        'variant_id':    selectedVariant?['id'],
        'product_name':  bike['product_name'],
        'image':         (selectedVariant?['image'] ?? bike['image']),
        'variant_type':  selectedVariant?['variant_type'],
        'variant_value': selectedVariant?['variant_value'],
        'price':         basePrice + adj,
        'quantity':      quantity,
        'stock':         stock,
      }
    ]);
  }

  /// Cart checkout — one or more cart lines, quantity managed on the Cart page itself.
  factory CheckoutPage.cart({required List<Map<String, dynamic>> cartItems}) {
    return CheckoutPage._(
      isCartCheckout: true,
      items: cartItems.map((c) => {
        'cart_item_id':  c['id'],
        'product_id':    c['product_id'],
        'variant_id':    c['variant_id'],
        'product_name':  c['product_name'],
        'image':         (c['variant_image'] ?? c['image']),
        'variant_type':  c['variant_type'],
        'variant_value': c['variant_value'],
        'price':         double.tryParse(c['price']?.toString() ?? '0') ?? 0,
        'quantity':      int.tryParse(c['quantity']?.toString() ?? '1') ?? 1,
        'stock':         null,
      }).toList(),
    );
  }

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late List<Map<String, dynamic>> _items;
  String _deliveryType = 'delivery'; // 'delivery' | 'pickup'

  Map<String, dynamic>? _user;
  bool _loadingUser = true;

  double? _deliveryFee;
  bool _loadingFee = false;

  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final u = await ApiService.getProfile();
      if (mounted) setState(() { _user = u; _loadingUser = false; });
      _fetchDeliveryFee();
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _fetchDeliveryFee() async {
    final city = _user?['address_city']?.toString();
    if (city == null || city.isEmpty || _deliveryType != 'delivery') {
      setState(() => _deliveryFee = null);
      return;
    }
    setState(() => _loadingFee = true);
    try {
      final res = await ApiService.getDeliveryFeeByCity(city);
      if (mounted) {
        setState(() {
          _deliveryFee = double.tryParse(res['fee']?.toString() ?? '150') ?? 150;
          _loadingFee = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _deliveryFee = 150.0; _loadingFee = false; });
    }
  }

  String? _u(String key) => _user != null ? (_user![key]?.toString()) : null;

  double get _subtotal => _items.fold(0.0, (sum, it) {
    final price = (it['price'] as num?)?.toDouble() ?? 0;
    final qty   = (it['quantity'] as num?)?.toInt() ?? 1;
    return sum + (price * qty);
  });

  double get _fee => _deliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0);
  double get _total => _subtotal + _fee;

  bool get _addressComplete =>
      (_user?['address_city'] ?? '').toString().trim().isNotEmpty &&
      (_user?['address_street'] ?? '').toString().trim().isNotEmpty;

  Future<void> _editAddress() async {
    final streetCtrl   = TextEditingController(text: _user?['address_street']?.toString() ?? '');
    final barangayCtrl = TextEditingController(text: _user?['address_barangay']?.toString() ?? '');
    final cityCtrl     = TextEditingController(text: _user?['address_city']?.toString() ?? '');
    final provinceCtrl = TextEditingController(text: _user?['address_province']?.toString() ?? 'Bataan');
    final zipCtrl      = TextEditingController(text: _user?['address_zipcode']?.toString() ?? '');
    final landmarkCtrl = TextEditingController(text: _user?['address_landmark']?.toString() ?? '');
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setBS) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text("Delivery Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 20),
            _addrField(streetCtrl, "Street / House No."),
            const SizedBox(height: 14),
            _addrField(barangayCtrl, "Barangay"),
            const SizedBox(height: 14),
            _addrField(cityCtrl, "City / Municipality"),
            const SizedBox(height: 14),
            _addrField(provinceCtrl, "Province"),
            const SizedBox(height: 14),
            _addrField(zipCtrl, "Zip Code", type: TextInputType.number),
            const SizedBox(height: 14),
            _addrField(landmarkCtrl, "Landmark (optional)"),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
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
                    if (ctx.mounted) Navigator.pop(ctx);
                  } on ApiException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  } finally {
                    setBS(() => saving = false);
                  }
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

    await _loadUser();
  }

  Widget _addrField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
    child: TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
  );

  Future<void> _confirm() async {
    if (_deliveryType == 'delivery' && !_addressComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please add a delivery address first"),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _placingOrder = true);
    try {
      final paymentMethod = _deliveryType == 'delivery' ? 'cash_on_delivery' : 'cash_on_pickup';
      Map<String, dynamic> res;

      if (widget.isCartCheckout) {
        res = await ApiService.placeOrder(
          paymentMethod:   paymentMethod,
          deliveryType:    _deliveryType,
          addressStreet:   _deliveryType == 'delivery' ? (_u('address_street'))   : null,
          addressBarangay: _deliveryType == 'delivery' ? (_u('address_barangay')) : null,
          addressCity:     _deliveryType == 'delivery' ? (_u('address_city'))     : null,
          addressProvince: _deliveryType == 'delivery' ? (_u('address_province')) : null,
          addressZipcode:  _deliveryType == 'delivery' ? (_u('address_zipcode'))  : null,
          addressLandmark: _deliveryType == 'delivery' ? (_u('address_landmark')) : null,
        );
        await ApiService.clearCart().catchError((_) => <String, dynamic>{});
      } else {
        final item = _items.first;
        res = await ApiService.placeDirectOrder(
          productId:     item['product_id'] as int,
          quantity:      item['quantity'] as int,
          variantId:     item['variant_id'] as int?,
          paymentMethod: paymentMethod,
          deliveryType:  _deliveryType,
          addressStreet:   _deliveryType == 'delivery' ? (_u('address_street'))   : null,
          addressBarangay: _deliveryType == 'delivery' ? (_u('address_barangay')) : null,
          addressCity:     _deliveryType == 'delivery' ? (_u('address_city'))     : null,
          addressProvince: _deliveryType == 'delivery' ? (_u('address_province')) : null,
          addressZipcode:  _deliveryType == 'delivery' ? (_u('address_zipcode'))  : null,
          addressLandmark: _deliveryType == 'delivery' ? (_u('address_landmark')) : null,
        );
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AppColors.primaryGlow, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text("Order Placed!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text("Ref: ${res['reference_number']}",
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Text("Total: ₱${res['total_amount']}", style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Done", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outsideBataan = (_user?['address_province'] ?? '').toString().isNotEmpty &&
        _user!['address_province'].toString().toLowerCase() != 'bataan';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("ORDER SUMMARY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ..._items.map(_itemCard),
                const SizedBox(height: 8),

                const SizedBox(height: 12),
                const Text("DELIVERY METHOD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _methodChip("🚴 Delivery", 'delivery')),
                  const SizedBox(width: 10),
                  Expanded(child: _methodChip("🏪 Pickup", 'pickup')),
                ]),
                const SizedBox(height: 16),

                if (_deliveryType == 'delivery') ...[
                  const Text("DELIVERY ADDRESS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: _addressComplete
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              [
                                _user?['address_street'], _user?['address_barangay'],
                                _user?['address_city'], _user?['address_province'], _user?['address_zipcode'],
                              ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(', '),
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5),
                            ),
                            if ((_user?['address_landmark'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text("Landmark: ${_user!['address_landmark']}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                            if (outsideBataan) ...[
                              const SizedBox(height: 8),
                              const Text("⚠ This address is outside Bataan. Delivery may not be available.",
                                  style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _editAddress,
                              child: const Row(children: [
                                Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text("Edit Address", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ])
                        : GestureDetector(
                            onTap: _editAddress,
                            child: const Row(children: [
                              Icon(Icons.add_location_alt_outlined, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text("Add delivery address", style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: const Row(children: [
                      Icon(Icons.storefront_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text(ShopInfo.address, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Column(children: [
                    _totalRow("Subtotal", "₱${_subtotal.toStringAsFixed(2)}"),
                    const SizedBox(height: 8),
                    _totalRow("Delivery Fee", _deliveryType == 'pickup' ? "₱0.00" : (_loadingFee ? "…" : "₱${(_deliveryFee ?? 0).toStringAsFixed(2)}")),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    _totalRow("Total", "₱${_total.toStringAsFixed(2)}", bold: true),
                  ]),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(children: [
                    const Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(_deliveryType == 'delivery' ? "Cash on Delivery" : "Cash on Pickup",
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 100),
              ],
            ),
      bottomNavigationBar: _loadingUser ? null : Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.divider))),
        child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _placingOrder ? null : _confirm,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _placingOrder
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : Text("Place Order — ₱${_total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final img = AppConstants.imageUrl(item['image']?.toString());
    final hasVariant = item['variant_type'] != null && item['variant_value'] != null;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final qty   = (item['quantity'] as num?)?.toInt() ?? 1;
    final stock = item['stock'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: img.isNotEmpty
              ? CachedNetworkImage(imageUrl: img, width: 60, height: 60, fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(width: 60, height: 60, color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 24)))
              : Container(width: 60, height: 60, color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['product_name']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (hasVariant) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(5)),
              child: Text("${item['variant_type']}: ${item['variant_value']}", style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 8),
          if (!widget.isCartCheckout)
            Row(children: [
              _qtyBtn(Icons.remove, () { if (qty > 1) setState(() => item['quantity'] = qty - 1); }),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text("$qty", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              _qtyBtn(Icons.add, () { if (stock == null || qty < stock) setState(() => item['quantity'] = qty + 1); }),
            ])
          else
            Text("₱${price.toStringAsFixed(2)} × $qty", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Text("₱${(price * qty).toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ]),
    );
  }

  Widget _methodChip(String label, String value) {
    final active = _deliveryType == value;
    return GestureDetector(
      onTap: () { setState(() => _deliveryType = value); _fetchDeliveryFee(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.black : AppColors.textMuted))),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) => Row(children: [
    Text(label, style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textMuted, fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(color: bold ? AppColors.primary : AppColors.textPrimary, fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
  ]);

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
      child: Icon(icon, size: 14, color: AppColors.textPrimary),
    ),
  );
}