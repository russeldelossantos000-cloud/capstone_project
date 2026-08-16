import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/customization_store.dart';
import 'cart_page.dart';

class CostEstimatorPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedProduct;

  const CostEstimatorPage({super.key, this.preselectedProduct});

  @override
  State<CostEstimatorPage> createState() => _CostEstimatorPageState();
}

class _CostEstimatorPageState extends State<CostEstimatorPage> {
  
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _groups   = [];

 
  Map<String, dynamic>? _selectedProduct;
  int _quantity = 1;

  
  bool _loadingProducts = true;
  bool _loadingGroups   = false;
  bool _addingToCart    = false;

  
  static const int _estimatorId = -999;

  @override
  void initState() {
    super.initState();
    CustomizationStore.clearProduct(_estimatorId);
    _fetchProducts();
    if (widget.preselectedProduct != null) {
      _selectedProduct = widget.preselectedProduct;
      _loadGroups();
    }
  }

  @override
  void dispose() {
    CustomizationStore.clearProduct(_estimatorId);
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final all = await ApiService.getProducts();
      if (mounted) setState(() { _products = all; _loadingProducts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    CustomizationStore.clearProduct(_estimatorId);
    try {
      final groups = await ApiService.getAllCustomizationsWithOptions();
      if (mounted) setState(() { _groups = groups; _loadingGroups = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  double get _basePrice =>
      double.tryParse(_selectedProduct?['price']?.toString() ?? '0') ?? 0.0;

  double get _addons =>
      CustomizationStore.getAdditionalCost(_estimatorId);

  double get _unitTotal => _basePrice + _addons;
  double get _grandTotal => _unitTotal * _quantity;

  String _imageUrl(Map<String, dynamic>? p) {
    if (p == null) return '';
    final raw = (p['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('uploads/')) return 'http://${AppConstants.serverIp}/$raw';
    return '${AppConstants.imageUrl}/$raw';
  }

  Future<void> _addToCart() async {
    if (_selectedProduct == null) {
      _msg("Please select a bike first", error: true); return;
    }
    setState(() => _addingToCart = true);
    try {
      await ApiService.addToCart(_selectedProduct!['id'] as int, _quantity);
      if (!mounted) return;
      _msg("Added to cart! Customizations will be applied at checkout.");
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
      }
    } on ApiException catch (e) {
      _msg(e.message, error: true);
    } finally {
      if (mounted) setState(() => _addingToCart = false);
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
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("Cost Estimator",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() { _selectedProduct = null; _groups = []; _quantity = 1; });
              CustomizationStore.clearProduct(_estimatorId);
            },
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              
              _stepHeader("1", "Select a Bike"),
              const SizedBox(height: 10),
              _loadingProducts
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                  : _bikePicker(),
              const SizedBox(height: 20),

              
              _stepHeader("2", "Quantity"),
              const SizedBox(height: 10),
              _qtySelector(),
              const SizedBox(height: 20),

             
              _stepHeader("3", "Customization Options",
                  subtitle: _selectedProduct == null ? "Select a bike first" : null),
              const SizedBox(height: 10),
              if (_selectedProduct == null)
                _lockedSection()
              else if (_loadingGroups)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
              else if (_groups.isEmpty)
                _emptyGroups()
              else
                ..._groups.map((g) => _customizationGroup(g)),
              const SizedBox(height: 20),

              
              _stepHeader("4", "Cost Breakdown"),
              const SizedBox(height: 10),
              _costBreakdown(),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: _bottomBar(),
    );
  }

  
  Widget _stepHeader(String num, String title, {String? subtitle}) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Center(child: Text(num, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black))),
    ),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      if (subtitle != null)
        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]),
  ]);

  
  Widget _bikePicker() => SizedBox(
    height: 160,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        final isSelected = _selectedProduct?['id'] == p['id'];
        final url = _imageUrl(p);
        return GestureDetector(
          onTap: () {
            setState(() => _selectedProduct = p);
            _loadGroups();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 130,
            margin: EdgeInsets.only(right: 10, left: i == 0 ? 0 : 0),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryGlow : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: SizedBox(
                  height: 88, width: double.infinity,
                  child: url.isNotEmpty
                      ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 36)))
                      : Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 36)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['product_name']?.toString() ?? '',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text("₱${p['price']}",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                            color: isSelected ? AppColors.primary : AppColors.textMuted)),
                  ]),
                ),
              ),
              if (isSelected) Container(
                width: double.infinity, height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                ),
              ),
            ]),
          ),
        );
      },
    ),
  );

  
  Widget _qtySelector() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(children: [
      const Text("Quantity", style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const Spacer(),
      _qtyBtn(Icons.remove, () { if (_quantity > 1) setState(() => _quantity--); }),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text("$_quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      _qtyBtn(Icons.add, () => setState(() => _quantity++)),
    ]),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
      child: Icon(icon, size: 16, color: AppColors.textPrimary),
    ),
  );

  
  Widget _lockedSection() => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
      const SizedBox(width: 8),
      const Text("Select a bike above to unlock customizations",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    ]),
  );

  Widget _emptyGroups() => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
    child: const Text("No customization groups configured yet.",
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  );

  
  Widget _customizationGroup(Map<String, dynamic> group) {
    final groupId   = group['id'] as int;
    final groupName = group['name']?.toString() ?? '';
    final options   = (group['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selected  = CustomizationStore.getSelection(_estimatorId, groupId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected != null ? AppColors.primary.withOpacity(0.4) : AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(groupName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          if (selected != null) GestureDetector(
            onTap: () { setState(() => CustomizationStore.deselect(_estimatorId, groupId)); },
            child: const Text("Clear", style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected?['id'] == opt['id'];
            final price = double.tryParse(opt['additional_price']?.toString() ?? '0') ?? 0.0;
            return GestureDetector(
              onTap: () => setState(() => isSelected
                  ? CustomizationStore.deselect(_estimatorId, groupId)
                  : CustomizationStore.select(_estimatorId, groupId, opt)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder, width: isSelected ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                    const SizedBox(width: 4),
                  ],
                  Text(opt['option_name']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.black : AppColors.textPrimary)),
                  if (price > 0) ...[
                    const SizedBox(width: 4),
                    Text("+₱${price.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 10, color: isSelected ? Colors.black87 : AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  
  Widget _costBreakdown() {
    final selections = CustomizationStore.getSelections(_estimatorId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_selectedProduct == null)
          const Text("Select a bike to see the breakdown",
              style: TextStyle(color: AppColors.textMuted, fontSize: 13))
        else ...[
          _breakdownRow("Base price — ${_selectedProduct!['product_name']}", "₱${_basePrice.toStringAsFixed(2)}"),
          if (selections.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            ...selections.entries.map((e) {
              final optName = e.value['option_name']?.toString() ?? '';
              final extra   = double.tryParse(e.value['additional_price']?.toString() ?? '0') ?? 0.0;
              // Find group name
              final group = _groups.firstWhere((g) => g['id'] == e.key, orElse: () => {});
              final groupName = group['name']?.toString() ?? 'Option';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _breakdownRow("  $groupName: $optName",
                    extra > 0 ? "+₱${extra.toStringAsFixed(2)}" : "Free",
                    valueColor: extra > 0 ? AppColors.primary : AppColors.success),
              );
            }),
          ],
          if (_quantity > 1) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            _breakdownRow("Unit total", "₱${_unitTotal.toStringAsFixed(2)}"),
            _breakdownRow("Quantity", "× $_quantity"),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(children: [
            const Text("ESTIMATED TOTAL",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
            const Spacer(),
            Text("₱${_grandTotal.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
        ],
      ]),
    );
  }

  Widget _breakdownRow(String label, String value, {Color? valueColor}) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
  ]);

 
  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ESTIMATE", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        Text(
          _selectedProduct == null ? "₱0.00" : "₱${_grandTotal.toStringAsFixed(2)}",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
        ),
        if (_quantity > 1)
          Text("$_quantity units × ₱${_unitTotal.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ])),
      const SizedBox(width: 12),
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: (_selectedProduct == null || _addingToCart) ? null : _addToCart,
          icon: _addingToCart
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 20),
          label: const Text("Add to Cart",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedProduct == null ? AppColors.textMuted : AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]),
  );
}
